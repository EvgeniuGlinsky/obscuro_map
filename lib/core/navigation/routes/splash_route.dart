import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:obscuro_map/features/splash/ui/splash_page.dart';

part 'splash_route.g.dart';

@TypedGoRoute<SplashRoute>(
  path: '/splash',
  name: 'splash',
)
class SplashRoute extends GoRouteData with $SplashRoute {
  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const SplashPage();
  }
}
