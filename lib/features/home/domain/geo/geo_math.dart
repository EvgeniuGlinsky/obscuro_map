import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/map_constants.dart';

/// Great-circle distance in metres between two coordinates (Haversine).
double haversineMeters(LatLng a, LatLng b) {
  final lat1 = a.latitude * pi / 180;
  final lat2 = b.latitude * pi / 180;
  final dLat = (b.latitude - a.latitude) * pi / 180;
  final dLon = (b.longitude - a.longitude) * pi / 180;
  final sinDLat = sin(dLat / 2);
  final sinDLon = sin(dLon / 2);
  final h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon;
  return 2 * kEarthRadiusMeters * atan2(sqrt(h), sqrt(1 - h));
}

/// Perpendicular distance in metres from [p] to segment [a]→[b].
/// Equirectangular projection — accurate to <0.1 % for segments < 100 km.
double crossTrackMeters(LatLng p, LatLng a, LatLng b) {
  const toRad = pi / 180.0;
  final k = cos((a.latitude + b.latitude) / 2 * toRad);

  final ax = a.longitude * toRad * k, ay = a.latitude * toRad;
  final bx = b.longitude * toRad * k, by = b.latitude * toRad;
  final px = p.longitude * toRad * k, py = p.latitude * toRad;

  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0.0) {
    final ex = px - ax, ey = py - ay;
    return sqrt(ex * ex + ey * ey) * kEarthRadiusMeters;
  }
  return ((dx * (ay - py) - dy * (ax - px)).abs() / sqrt(len2)) *
      kEarthRadiusMeters;
}
