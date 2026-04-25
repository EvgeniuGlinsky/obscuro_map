import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../entities/remote_progress.dart';

abstract interface class IRemoteProgressRepository {
  /// Returns the cloud-side progress for [uid], or `null` when no document
  /// exists yet (first-time sign-in).
  Future<RemoteProgress?> load(String uid);

  /// Writes the full track + fill snapshot to the user's document. Existing
  /// arrays are replaced (last-write-wins).
  Future<void> save(
    String uid, {
    required List<LatLng> points,
    required List<LatLng> fillPoints,
  });
}
