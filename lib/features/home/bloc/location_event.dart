import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/hex/hex_index.dart';

sealed class LocationEvent {
  const LocationEvent();
}

final class LocationStarted extends LocationEvent {
  const LocationStarted();
}

/// Removes every explored cell whose centroid lies within [radiusMeters] of
/// [center]. Persists immediately — the gesture-end debounce only matters
/// for cloud mirroring, which is dispatched via [LocationProgressSaved].
final class LocationCellsErased extends LocationEvent {
  const LocationCellsErased({required this.center, required this.radiusMeters});
  final LatLng center;
  final double radiusMeters;
}

/// Persists current state and pushes it to the cloud. Fired on gesture end
/// to debounce cloud writes during continuous erase strokes.
final class LocationProgressSaved extends LocationEvent {
  const LocationProgressSaved();
}

/// Adds a batch of cells (e.g. produced by the flood-fill use case) to the
/// explored set. Idempotent — already-explored cells are no-ops.
final class LocationCellsAdded extends LocationEvent {
  const LocationCellsAdded(this.cells);
  final Iterable<HexIndex> cells;
}

/// Internal: fires when the auth state changes. [uid] is `null` while
/// signed out. Triggers a one-time cloud sync per uid on sign-in.
final class LocationAuthChanged extends LocationEvent {
  const LocationAuthChanged(this.uid);
  final String? uid;
}
