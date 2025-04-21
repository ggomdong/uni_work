import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../views/main_navigation_screen.dart';
import '../repos/authentication_repo.dart';
import '../views/login_screen.dart';

final routerProvider = Provider((ref) {
  return GoRouter(
    initialLocation: "/home",
    redirect: (context, state) {
      final isLoggedIn = ref.read(authRepo).isLoggedIn;
      if (!isLoggedIn && state.matchedLocation != LoginScreen.routeUrl) {
        return LoginScreen.routeUrl;
      }
      return null;
    },
    routes: [
      GoRoute(
        name: LoginScreen.routeName,
        path: LoginScreen.routeUrl,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: "/:tab(home|calendar|profile)",
        builder: (context, state) {
          final tab = state.pathParameters["tab"] ?? "";
          return MainNavigationScreen(tab: tab);
        },
      ),
    ],
  );
});
