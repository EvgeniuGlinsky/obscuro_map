import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:obscuro_map/features/home/ui/home_page.dart';

part 'home_route.g.dart';

@TypedGoRoute<HomeRoute>(
  path: '/home',
  name: 'home',
)
class HomeRoute extends GoRouteData with $HomeRoute {
  final TileLayer $extra;

  HomeRoute({required this.$extra});

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return HomePage(map: $extra);
  }
}
