import 'package:flutter_map/flutter_map.dart';

sealed class SplashState {}

final class InitialSplashState extends SplashState {}

final class SuccessSplashState extends SplashState {
  final TileLayer map;

  SuccessSplashState({required this.map});
}
