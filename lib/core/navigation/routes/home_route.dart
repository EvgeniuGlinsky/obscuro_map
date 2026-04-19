import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:obscuro_map/features/home/ui/home_page.dart';

part 'home_route.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/home',
  name: 'home',
)
class HomeRoute extends GoRouteData with $HomeRoute {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const HomePage();
  }
}
