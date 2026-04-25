import 'package:google_maps_flutter/google_maps_flutter.dart';

sealed class LocationState {
  const LocationState();
}

final class LocationInitial extends LocationState {
  const LocationInitial();
}

final class LocationTracking extends LocationState {
  const LocationTracking(this.points, {this.fillPoints = const []});

  final List<LatLng> points;
  final List<LatLng> fillPoints;
}

final class LocationPermissionDenied extends LocationState {
  const LocationPermissionDenied();
}