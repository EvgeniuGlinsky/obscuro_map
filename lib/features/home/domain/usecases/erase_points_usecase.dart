import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../geo/geo_math.dart';

/// Result of an erase operation — the new track and fill point lists with
/// every coordinate inside the erase radius removed.
class EraseResult {
  const EraseResult({required this.points, required this.fillPoints});

  final List<LatLng> points;
  final List<LatLng> fillPoints;
}

/// Removes every track / fill point within [radiusMeters] of [center].
/// Uses Haversine for an accurate spherical distance check independent of
/// projection.
@lazySingleton
class ErasePointsUseCase {
  const ErasePointsUseCase();

  EraseResult call({
    required List<LatLng> points,
    required List<LatLng> fillPoints,
    required LatLng center,
    required double radiusMeters,
  }) {
    bool outside(LatLng p) => haversineMeters(p, center) > radiusMeters;
    return EraseResult(
      points: points.where(outside).toList(growable: false),
      fillPoints: fillPoints.where(outside).toList(growable: false),
    );
  }
}
