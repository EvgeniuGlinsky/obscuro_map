import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Snapshot of a user's progress as stored in Firestore.
class RemoteProgress {
  const RemoteProgress({
    required this.points,
    required this.fillPoints,
  });

  final List<LatLng> points;
  final List<LatLng> fillPoints;

  bool get isEmpty => points.isEmpty && fillPoints.isEmpty;
}
