import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../view_models/auth_state_view_model.dart';
import '../views/splash_screen.dart';
import '../views/main_navigation_screen.dart';
import '../views/login_screen.dart';

// “상세 화면 push” 같은 케이스 대비
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class RouteURL {
  static const splash = "/splash";
  static const login = "/login";
  static const home = "/home";
  static const tab = "/:tab(home|calendar|stat|profile)";
}

class RouteName {
  static const splash = "splash";
  static const login = "login";
  static const home = "home";
}

final routerProvider = Provider((ref) {
  final auth = ref.watch(authStateProvider);
  final loggedIn = auth.loggedIn;
  final splashShown = auth.splashShown;

  return GoRouter(
    initialLocation: RouteURL.splash,
    observers: [routeObserver],
    redirect: (context, state) {
      final loc = state.matchedLocation;

      final isSplash = loc == RouteURL.splash;
      final isLogin = loc == RouteURL.login;

      // 이미 스플래시를 본 뒤에는 /splash 접근을 막는다
      if (splashShown && isSplash) {
        return loggedIn ? RouteURL.home : RouteURL.login;
      }

      // (스플래시를 아직 안 봤으면, 최초 1회는 스플래시 허용)
      if (!splashShown) {
        if (!isSplash) return RouteURL.splash;
        return null;
      }

      // 인증 가드
      if (!loggedIn) {
        if (!isLogin) return RouteURL.login;
        return null;
      }

      if (loggedIn && isLogin) return RouteURL.home;

      return null;
    },
    routes: [
      GoRoute(
        name: RouteName.splash,
        path: RouteURL.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        name: RouteName.login,
        path: RouteURL.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteURL.tab,
        builder: (context, state) {
          final tab = state.pathParameters["tab"] ?? "";
          return MainNavigationScreen(tab: tab);
        },
      ),
    ],
  );
});
