import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:obscuro_map/features/splash/splash_view.dart';

part 'splash_route.g.dart';

@TypedGoRoute<SplashRoute>(
  path: '/',
  name: 'splash',
)
class SplashRoute extends GoRouteData with $SplashRoute {
  const SplashRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const SplashView();
  }
}
