import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../views/widgets/snackbar.dart';
import '../repos/authentication_repo.dart';

class LoginViewModel extends AsyncNotifier<void> {
  late final AuthenticationRepository _repository;

  @override
  FutureOr<void> build() {
    _repository = ref.read(authRepo);
  }

  Future<void> login(
    String username,
    String password,
    BuildContext context,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async => await _repository.login(username, password),
    );
    if (state.hasError) {
      showSnackBar(context, "로그인에 실패하였습니다.", Colors.red);
    } else {
      context.go("/home");
    }
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
