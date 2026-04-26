import 'package:go_router/go_router.dart';

import 'routes/home_route.dart';
import 'routes/splash_route.dart';

abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      $splashRoute,
      $homeRoute,
    ],
  );
}
