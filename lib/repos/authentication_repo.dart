import 'dart:io';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../view_models/auth_state_view_model.dart';

class AuthenticationRepository {
  final Dio _dio = Dio();
  late final FlutterSecureStorage _secureStorage;
  late final SharedPreferences _prefs;
  final void Function(bool loggedIn)? onAuthStateChanged;

  // key값들을 상수로 정의
  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _isLoggedInKey = 'isLoggedIn';

  Logger logger = Logger();

  AuthenticationRepository(
    this._secureStorage,
    this._prefs, {
    this.onAuthStateChanged,
  }) {
    final baseUrl = dotenv.env['API_URL'];
    if (baseUrl == null || baseUrl.isEmpty) {
      throw Exception('API_URL is not configured');
    }
    _dio.options.baseUrl = baseUrl;

    // 🔥 URL 확인
    logger.i('🔥[AUTH][INIT] baseUrl = ${_dio.options.baseUrl}');

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 기기에 저장된 accessToken 로드
          final token = await _secureStorage.read(key: _accessTokenKey);

          // 토큰이 있으면, 매 요청마다 헤더에 accessToken 포함
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // 🔥 요청 로그 확인
          // print('🔥[DIO][REQUEST] ${options.method} ${options.uri}');
          // print('🔥[DIO][REQUEST] headers: ${options.headers}');
          // print('🔥[DIO][REQUEST] data: ${options.data}');

          return handler.next(options);
        },
        onError: (error, handler) async {
          // 🔥 에러 로그 확인
          // print('🔥[DIO][ERROR] type=${error.type} message=${error.message}');
          // print(
          //   '🔥[DIO][ERROR] response=${error.response?.statusCode} ${error.response?.data}',
          // );
          final statusCode = error.response?.statusCode;
          final data = error.response?.data;
          final errorCode =
              (data is Map<String, dynamic>) ? data['error'] : null;

          final path = error.requestOptions.path;
          final normalized = path.startsWith('/') ? path.substring(1) : path;
          final isTokenObtain =
              normalized.startsWith('api/token/') &&
              !normalized.startsWith('api/token/refresh/');
          final isTokenRefresh = normalized.startsWith('api/token/refresh/');

          // 로그인 요청은 인터셉터에서 logout 개입 금지
          if (isTokenObtain) {
            return handler.reject(error);
          }

          // 일반 API에서만 퇴사자 감지 → 즉시 logout
          if (!isTokenObtain && statusCode == 403 && errorCode == 'out_user') {
            await logout();
            return handler.reject(error);
          }

          if (statusCode == 401 &&
              (data is Map<String, dynamic>) &&
              data['code'] == 'token_not_valid' &&
              !isTokenRefresh) {
            final refreshToken = await _secureStorage.read(
              key: _refreshTokenKey,
            );
            if (refreshToken != null) {
              try {
                final response = await _dio.post(
                  'api/token/refresh/',
                  data: {'refresh': refreshToken},
                );
                final newAccessToken = response.data['access'];
                final newRefreshToken = response.data['refresh'];

                await _secureStorage.write(
                  key: _accessTokenKey,
                  value: newAccessToken,
                );
                await _secureStorage.write(
                  key: _refreshTokenKey,
                  value: newRefreshToken,
                );

                final newOptions = error.requestOptions.copyWith(
                  headers: {
                    ...error.requestOptions.headers,
                    'Authorization': 'Bearer $newAccessToken',
                  },
                  queryParameters: Map<String, dynamic>.from(
                    error.requestOptions.queryParameters,
                  ),
                );

                final retryResponse = await _dio.fetch(newOptions);
                return handler.resolve(retryResponse);
              } catch (_) {
                await logout();
                return handler.reject(error);
              }
            }
          }

          // token_not_valid가 아니더라도 401이면 세션 정리(일반 API 기준)
          if (statusCode == 401) {
            await logout();
            return handler.reject(error);
          }

          return handler.reject(error);
        },
      ),
    );
  }

  bool get isLoggedIn => _prefs.getBool(_isLoggedInKey) ?? false;
  Dio get dio => _dio;

  Future<bool> checkActiveUser() async {
    try {
      // 재직 여부 확인용 간단 API (백엔드에서는 ProfileAPIView에 퇴사자 가드 추가된 상태)
      await _dio.get('api/profile/');

      // 여기까지 왔으면 200 OK → 재직자
      return true;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final errorCode = e.response?.data['error'];

      // 퇴사자
      if (statusCode == 403 && errorCode == 'out_user') {
        await logout(); // 토큰/플래그 제거
        return false;
      }

      // 그 외 인증 문제도 여기에서 로컬 세션 정리
      if (statusCode == 401 || statusCode == 403) {
        await logout();
        return false;
      }

      // 네트워크 등 기타 에러는 정책에 따라 처리 (여기선 보수적으로 false)
      return false;
    } catch (_) {
      // 예외적으로 뭔가 또 터지면 역시 로그아웃
      await logout();
      return false;
    }
  }

  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      // device_info_plus removed androidId. Use android_id package instead.
      const androidIdPlugin = AndroidId();
      final androidId = await androidIdPlugin.getId();
      return (androidId == null || androidId.isEmpty) ? 'unknown' : androidId;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown';
    } else {
      return 'unsupported';
    }
  }

  Future<bool> login(String username, String password) async {
    try {
      final deviceId = await getDeviceId();
      final response = await _dio.post(
        'api/token/',
        data: {
          'username': username,
          'password': password,
          'device_id': deviceId,
        },
      );

      await _secureStorage.write(
        key: _accessTokenKey,
        value: response.data['access'],
      );
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: response.data['refresh'],
      );
      await _prefs.setBool(_isLoggedInKey, true);
      // onAuthStateChanged?.call(true);

      return true;
    } on DioException catch (e) {
      final String message = e.response?.data['message'] ?? '로그인 실패';
      throw message;
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _prefs.setBool(_isLoggedInKey, false);
    onAuthStateChanged?.call(false);
  }

  Future<bool> refreshToken() async {
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null) return false;

    try {
      final response = await _dio.post(
        'api/token/refresh/',
        data: {'refresh': refreshToken},
      );
      await _secureStorage.write(
        key: _accessTokenKey,
        value: response.data['access'],
      );
      await _secureStorage.write(
        key: _refreshTokenKey,
        value: response.data['refresh'],
      );
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }
}

final authRepo = Provider((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final storage = const FlutterSecureStorage();
  return AuthenticationRepository(
    storage,
    prefs,
    onAuthStateChanged: (loggedIn) {
      final notifier = ref.read(authStateProvider.notifier);
      if (loggedIn) {
        notifier.setLoggedIn();
      } else {
        notifier.setLoggedOut();
      }
    },
  );
});

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);
