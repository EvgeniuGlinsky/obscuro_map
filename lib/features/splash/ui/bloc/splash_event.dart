import 'package:flutter_map/flutter_map.dart';

sealed class SplashEvent {}

final class OnMapLoadedSplashEvent extends SplashEvent {
  final TileLayer map;

  OnMapLoadedSplashEvent({required this.map});
}
