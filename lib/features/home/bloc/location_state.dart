import '../../../core/hex/hex_index.dart';

sealed class LocationState {
  const LocationState();
}

final class LocationInitial extends LocationState {
  const LocationInitial();
}

/// Steady state while the GPS stream is producing fixes. [cells] is the set
/// of every H3 cell the user has explored (track + fills collapsed — both
/// are "this hex is now revealed"). All cells are at
/// [kHexStorageResolution].
final class LocationTracking extends LocationState {
  const LocationTracking(this.cells, {this.lastCell});

  final Set<HexIndex> cells;

  /// Most recent cell the user occupied. Drives auto-center on first fix
  /// and lets the GPS handler skip path-fill work when the user hasn't
  /// crossed a cell boundary.
  final HexIndex? lastCell;
}

final class LocationPermissionDenied extends LocationState {
  const LocationPermissionDenied();
}
