import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../views/splash_screen.dart';
import '../views/main_navigation_screen.dart';
import '../views/login_screen.dart';

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
