import 'package:dio/dio.dart';
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
    _dio.options.baseUrl = const String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'http://localhost:8000/',
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // 기기에 저장된 accessToken 로드
          final token = await _secureStorage.read(key: _accessTokenKey);

          // 토큰이 있으면, 매 요청마다 헤더에 accessToken 포함
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
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

                final retryResponse = await _dio.request(
                  error.requestOptions.path,
                  options: Options(
                    method: error.requestOptions.method,
                    headers: {'Authorization': 'Bearer $newAccessToken'},
                  ),
                  data: error.requestOptions.data,
                );

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

  Stream<bool> authStateChanges() async* {
    yield isLoggedIn;
    await for (final _
        in _secureStorage.read(key: _accessTokenKey).asStream()) {
      yield isLoggedIn;
    }
  }

  Future<void> login(String username, String password) async {
    final response = await _dio.post(
      'api/token/',
      data: {'username': username, 'password': password},
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

  // Future<bool> validateAutoLogIn() async {
  //   // isLoggedIn 체크
  //   if (!await isLoggedIn()) return false;

  //   // Token 유효성 체크
  //   final accessToken = await _secureStorage.read(key: _accessTokenKey);
  //   final refreshToken = await _secureStorage.read(key: _refreshTokenKey);

  //   if (accessToken == null || refreshToken == null) {
  //     _logger.w("토큰이 없습니다.");
  //     return false;
  //   }

  //   try {
  //     // refreshToken의 유효성 확인 => 유효하면 accessToken 재발급 가능
  //     // 따라서, accessToken의 유효성 확인은 불필요함
  //     // header 추가는 불필요하고, 다른 logic을 방지하기 위해, authService를 이용하지 않음
  //     final response = await _dio.post(
  //       '${baseUrl}api/token/verify/',
  //       data: {'token': refreshToken},
  //       // options: Options(
  //       //   extra: {'interceptor': false}, // interceptor 무시 설정
  //       // ),
  //     );
  //     _logger.i("Refresh token is valid.");
  //     return response.statusCode == 200; // Token 모두 유효
  //   } catch (e) {
  //     _logger.w("Token is invalid or expired. Log out...");
  //     logout();
  //     return false;
  //   }
  // }
}

final authRepo = Provider((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final storage = const FlutterSecureStorage();
  return AuthenticationRepository(storage, prefs);
});

final authStateProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(authRepo);
  return repo.authStateChanges();
});

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);
