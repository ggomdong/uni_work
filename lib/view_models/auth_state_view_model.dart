import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repos/authentication_repo.dart';

class AuthState {
  final bool loggedIn;
  final bool splashShown; // 앱 프로세스에서 스플래시를 이미 보여줬는지

  const AuthState({required this.loggedIn, required this.splashShown});

  AuthState copyWith({bool? loggedIn, bool? splashShown}) {
    return AuthState(
      loggedIn: loggedIn ?? this.loggedIn,
      splashShown: splashShown ?? this.splashShown,
    );
  }
}

class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repo = ref.read(authRepo);
    return AuthState(
      loggedIn: repo.isLoggedIn,
      splashShown: false, // 프로세스 시작 시 false
    );
  }

  void setLoggedIn() => state = state.copyWith(loggedIn: true);
  void setLoggedOut() => state = state.copyWith(loggedIn: false);

  void markSplashShown() => state = state.copyWith(splashShown: true);
}

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthState>(
  AuthStateNotifier.new,
);
