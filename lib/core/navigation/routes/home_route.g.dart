// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_route.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [$homeRoute];

RouteBase get $homeRoute => GoRouteData.$route(
  path: '/home',
  name: 'home',
  factory: $HomeRoute._fromState,
);

mixin $HomeRoute on GoRouteData {
  static HomeRoute _fromState(GoRouterState state) =>
      HomeRoute($extra: state.extra as TileLayer);

  HomeRoute get _self => this as HomeRoute;

  @override
  String get location => GoRouteData.$location('/home');

  @override
  void go(BuildContext context) => context.go(location, extra: _self.$extra);

  @override
  Future<T?> push<T>(BuildContext context) =>
      context.push<T>(location, extra: _self.$extra);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location, extra: _self.$extra);

  @override
  void replace(BuildContext context) =>
      context.replace(location, extra: _self.$extra);
}
