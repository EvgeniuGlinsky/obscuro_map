import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/hex/h3_service.dart';
import '../../../../core/hex/hex_index.dart';
import '../geo/geo_math.dart';

/// Removes every visited cell whose centroid lies within [radiusMeters] of
/// [center]. Returns the new (smaller) set; never mutates the input.
@lazySingleton
class ErasePointsUseCase {
  const ErasePointsUseCase(this._h3);

  final H3Service _h3;

  Set<HexIndex> call({
    required Set<HexIndex> cells,
    required LatLng center,
    required double radiusMeters,
  }) {
    if (cells.isEmpty) return cells;

    // Bound the per-cell distance check to a candidate set: only cells
    // within a `kRing` of size ⌈radius / cellEdge⌉ can possibly match.
    // At storage resolution the average edge is ~24.9 m, so we round up
    // a couple of rings for safety.
    final centerCell = _h3.latLngToCell(center, kHexStorageResolution);
    const cellEdgeMeters = 24.9;
    final k = (radiusMeters / cellEdgeMeters).ceil() + 1;
    final candidates = _h3.diskAroundCell(centerCell, k).toSet();

    final result = <HexIndex>{};
    for (final cell in cells) {
      if (candidates.contains(cell)) {
        final c = _h3.cellToLatLng(cell);
        if (haversineMeters(c, center) <= radiusMeters) continue;
      }
      result.add(cell);
    }
    return result;
  }
}
