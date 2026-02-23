import 'package:go_router/go_router.dart';
import 'package:obscuro_map/core/navigation/routes/splash_route.dart';

sealed class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      $splashRoute,
    ],
  );
}
