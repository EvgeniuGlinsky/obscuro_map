import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/hex/h3_service.dart';
import '../../../../core/hex/hex_index.dart';

const int _kFillMaxCells = 4096;
const int _kFillBoundaryK = 64; // grid-distance from seed before "not enclosed"

sealed class FillResult {
  const FillResult();
}

final class FillSuccess extends FillResult {
  const FillSuccess(this.cells);
  final List<HexIndex> cells;
}

final class FillNotEnclosed extends FillResult {
  const FillNotEnclosed();
}

final class FillTooLarge extends FillResult {
  const FillTooLarge();
}

/// Floods outward from the seed cell using H3 neighbour traversal, treating
/// already-visited cells as walls. Reports:
///   * [FillSuccess] — the seed is enclosed; lists every newly-flooded cell.
///   * [FillNotEnclosed] — the flood reached the [_kFillBoundaryK] ring or
///     the seed is itself already visited.
///   * [FillTooLarge] — visited cells exceeded [_kFillMaxCells].
@lazySingleton
class ComputeFillAreaUseCase {
  const ComputeFillAreaUseCase(this._h3);

  final H3Service _h3;

  FillResult call(LatLng seed, Set<HexIndex> walls) {
    final seedCell = _h3.latLngToCell(seed, kHexStorageResolution);
    if (walls.contains(seedCell)) return const FillNotEnclosed();

    // Bounded BFS using H3 k-rings as the neighbour primitive.
    final visited = <HexIndex>{seedCell};
    final queue = <HexIndex>[seedCell];
    final boundary = _h3.diskAroundCell(seedCell, _kFillBoundaryK).toSet();

    var head = 0;
    while (head < queue.length) {
      if (visited.length > _kFillMaxCells) return const FillTooLarge();

      final cur = queue[head++];
      // 1-ring of `cur` minus `cur` itself = its 6 (or 5 at pentagons)
      // neighbours.
      for (final n in _h3.diskAroundCell(cur, 1)) {
        if (n == cur) continue;
        if (!boundary.contains(n)) return const FillNotEnclosed();
        if (walls.contains(n)) continue;
        if (visited.add(n)) queue.add(n);
      }
    }
    return FillSuccess(visited.toList(growable: false));
  }
}
