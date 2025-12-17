import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  return GoRouter(
    initialLocation: RouteURL.splash,
    observers: [routeObserver],
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
