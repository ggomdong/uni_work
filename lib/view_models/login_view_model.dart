import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repos/authentication_repo.dart';

class LoginViewModel extends AsyncNotifier<void> {
  late final AuthenticationRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.read(authRepo);
  }

  Future<bool> login(String username, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async => await _repository.login(username, password),
    );
    return !state.hasError;
  }

  Future<void> logout() async {
    await _repository.logout();
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
