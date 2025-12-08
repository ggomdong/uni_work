import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repos/authentication_repo.dart';

import '../view_models/attendance_view_model.dart';
import '../view_models/monthly_attendance_view_model.dart';
import '../view_models/profile_view_model.dart';

class LoginViewModel extends AsyncNotifier<void> {
  AuthenticationRepository get _repository => ref.read(authRepo);

  @override
  FutureOr<void> build() {}

  // 유저 바뀔 때마다 초기화 해야하는 provider들을 모아둔 함수
  void _invalidateUserScopedProviders() {
    // 홈
    ref.invalidate(attendanceProvider);

    // 캘린더
    ref.invalidate(monthlyAttendanceProvider);

    // 프로필
    ref.invalidate(profileViewModelProvider);

    // 추후 추가되는 provider는 하단에 추가
  }

  Future<bool> login(String username, String password) async {
    state = const AsyncValue.loading();

    final result = await AsyncValue.guard(
      () async => await _repository.login(username, password),
    );

    state = result;

    if (!result.hasError) {
      // 로그인 성공 → 새 유저 기준으로 다시 로딩되도록 기존 캐시 삭제
      _invalidateUserScopedProviders();
    }

    return !state.hasError;
  }

  Future<void> logout() async {
    await _repository.logout();

    _invalidateUserScopedProviders();
  }

  Future<void> checkAutoLogin() async {
    if (_repository.isLoggedIn) {
      await _repository.refreshToken();
    }
  }
}

final loginProvider = AsyncNotifierProvider<LoginViewModel, void>(
  () => LoginViewModel(),
);
