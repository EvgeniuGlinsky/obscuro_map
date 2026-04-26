import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/hex/h3_service.dart';
import '../../../../core/hex/hex_index.dart';

/// Result of feeding a GPS fix into the visited-cell set.
class VisitedCellsUpdate {
  const VisitedCellsUpdate({required this.added, required this.currentCell});

  /// Cells that became newly visited because of this fix. Empty when the
  /// user hasn't crossed a cell boundary.
  final List<HexIndex> added;

  /// The cell the user is currently in. Stored on the bloc so the next fix
  /// can fill any gaps along a fast-moving path.
  final HexIndex currentCell;
}

/// Translates a single GPS fix into the cells it traversed since the last
/// fix.
///
/// When two consecutive fixes land in adjacent cells, only the new cell
/// is added. When a fast mover (vehicle, etc.) skips intermediate cells,
/// `cellsAlongPath` interpolates so the fog reveal stays continuous.
@lazySingleton
class AppendTrackPointUseCase {
  const AppendTrackPointUseCase(this._h3);

  final H3Service _h3;

  VisitedCellsUpdate call({
    required LatLng position,
    required HexIndex? previousCell,
    required Set<HexIndex> visited,
  }) {
    final cell = _h3.latLngToCell(position, kHexStorageResolution);

    if (cell == previousCell) {
      // Still in the same cell — no work.
      return VisitedCellsUpdate(added: const [], currentCell: cell);
    }

    final added = <HexIndex>[];
    if (previousCell == null) {
      if (visited.add(cell)) added.add(cell);
    } else {
      for (final c in _h3.cellsAlongPath(previousCell, cell)) {
        if (visited.add(c)) added.add(c);
      }
    }
    return VisitedCellsUpdate(added: added, currentCell: cell);
  }
}
