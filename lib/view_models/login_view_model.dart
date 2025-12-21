import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repos/authentication_repo.dart';

import '../view_models/attendance_view_model.dart';
import '../view_models/auth_state_view_model.dart';
import '../view_models/monthly_attendance_view_model.dart';
import '../view_models/profile_view_model.dart';

class LoginViewModel extends AsyncNotifier<bool> {
  AuthenticationRepository get _repository => ref.read(authRepo);

  @override
  FutureOr<bool> build() => false;

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

    if (result.hasError) return false;

    // 1) 먼저 캐시 초기화
    _invalidateUserScopedProviders();

    // 2) 홈으로 보내기 전에 출근정보 1회 프리패치로 성공 확정
    final prefetch = await AsyncValue.guard(
      () async => await ref.read(attendanceProvider.future),
    );

    if (prefetch.hasError) {
      // 여기서 실패하면 Home에서 에러를 보여줄 게 아니라, 로그인 화면에서 실패로 처리하는 편이 낫다.
      // (퇴사자/401/네트워크 문제 등)
      state = AsyncValue.error(prefetch.error!, prefetch.stackTrace!);
      return false;
    }

    // 3) 그 다음에 로그인 상태 true → router가 home으로 이동
    ref.read(authStateProvider.notifier).setLoggedIn();
    return true;
  }

  Future<void> logout() async {
    await _repository.logout();

    _invalidateUserScopedProviders();
    state = const AsyncData(false);
  }

  Future<void> checkAutoLogin() async {
    if (_repository.isLoggedIn) {
      await _repository.refreshToken();
    }
  }
}

final loginProvider = AsyncNotifierProvider<LoginViewModel, bool>(
  () => LoginViewModel(),
);
