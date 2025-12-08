import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationRepository {
  final Dio _dio = Dio();
  late final FlutterSecureStorage _secureStorage;
  late final SharedPreferences _prefs;

  // key값들을 상수로 정의
  static const _accessTokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _isLoggedInKey = 'isLoggedIn';

  AuthenticationRepository(this._secureStorage, this._prefs) {
    _dio.options.baseUrl = dotenv.env['API_URL'] ?? 'http://localhost:8000/';

    // 🔥 URL 확인
    print('🔥[AUTH][INIT] baseUrl = ${_dio.options.baseUrl}');

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

          if (error.response?.statusCode == 401 &&
              error.response?.data['code'] == 'token_not_valid') {
            // 기기에 저장된 refreshToken 로드
            final refreshToken = await _secureStorage.read(
              key: _refreshTokenKey,
            );

            // 토큰이 있으면, 이를 이용해서 accessToken을 다시 받아온다.
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

                // 기존의 요청 복제 (쿼리, 데이터, 헤더 모두 유지)
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
          return handler.reject(error);
        },
      ),
    );
  }

  bool get isLoggedIn => _prefs.getBool(_isLoggedInKey) ?? false;
  Dio get dio => _dio;

  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
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
  return AuthenticationRepository(storage, prefs);
});

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);
