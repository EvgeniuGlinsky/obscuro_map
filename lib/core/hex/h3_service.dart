import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:h3_flutter/h3_flutter.dart';
import 'package:injectable/injectable.dart';

import 'hex_index.dart';

/// Thin wrapper around the `h3_flutter` (0.7.x) FFI bindings.
///
/// Centralising the package surface here means a future package swap touches
/// only this file. All callers work in [HexIndex] (Dart `int`); BigInt
/// (the package's `H3Index` typedef) crosses the FFI boundary and stops
/// here.
@lazySingleton
class H3Service {
  H3Service() : _h3 = const H3Factory().load();

  final H3 _h3;

  HexIndex latLngToCell(LatLng pos, int resolution) {
    final big = _h3.geoToCell(
      GeoCoord(lat: pos.latitude, lon: pos.longitude),
      resolution,
    );
    return big.toInt();
  }

  LatLng cellToLatLng(HexIndex cell) {
    final c = _h3.cellToGeo(BigInt.from(cell));
    return LatLng(c.lat, c.lon);
  }

  /// 6 vertices for a hex cell (5 for the 12 pentagons), winding CCW.
  List<LatLng> cellBoundary(HexIndex cell) {
    return _h3
        .cellToBoundary(BigInt.from(cell))
        .map((c) => LatLng(c.lat, c.lon))
        .toList(growable: false);
  }

  /// Cells within grid distance [k] of [origin] (k=0 → just origin, k=1 → 7
  /// cells, etc.). Used to convert a metric erase / reveal radius into a hex
  /// neighbourhood.
  List<HexIndex> diskAroundCell(HexIndex origin, int k) {
    return _h3
        .gridDisk(BigInt.from(origin), k)
        .map((b) => b.toInt())
        .toList(growable: false);
  }

  /// All cells along the grid path between two cells. Use this between
  /// consecutive GPS fixes so a fast-moving user never skips a hex even
  /// when samples are far apart.
  List<HexIndex> cellsAlongPath(HexIndex start, HexIndex end) {
    if (start == end) return [start];
    try {
      return _h3
          .gridPathCells(BigInt.from(start), BigInt.from(end))
          .map((b) => b.toInt())
          .toList(growable: false);
    } on Exception {
      // gridPathCells throws for distant pentagonal-zone-crossing pairs.
      // Fall back to just the endpoints — losing a couple of in-between
      // cells in the ocean is harmless for fog-of-war.
      return [start, end];
    }
  }

  /// Parent at coarser [resolution] (must be ≤ the cell's own resolution).
  HexIndex parentAt(HexIndex cell, int resolution) {
    return _h3.cellToParent(BigInt.from(cell), resolution).toInt();
  }

  int cellResolution(HexIndex cell) {
    return _h3.getResolution(BigInt.from(cell));
  }

  /// Base cell index (0–121). Cells 4, 14, 24, 38, 49, 58, 63, 72, 83, 97,
  /// 107, 117 are the 12 pentagons; the other 110 are hexagons.
  int baseCell(HexIndex cell) {
    return _h3.getBaseCellNumber(BigInt.from(cell));
  }

  /// All cells at [resolution] whose centroid lies inside [perimeter].
  /// `perimeter` is treated as a simple closed polygon (the closing edge is
  /// implicit). Used to enumerate cells visible in a viewport for the grid
  /// overlay.
  List<HexIndex> cellsInPolygon(List<LatLng> perimeter, int resolution) {
    final coords = perimeter
        .map((p) => GeoCoord(lat: p.latitude, lon: p.longitude))
        .toList(growable: false);
    return _h3
        .polygonToCells(perimeter: coords, resolution: resolution)
        .map((b) => b.toInt())
        .toList(growable: false);
  }

  /// Every cell on Earth at [resolution]. Counts grow by ×7 per step:
  /// res 0 → 122, res 1 → 842, res 2 → 5,882, res 3 → 41,162, etc.
  /// Use this only at very low resolutions where the viewport polygon
  /// approaches global coverage and `polygonToCells` becomes unreliable.
  List<HexIndex> allCellsAtResolution(int resolution) {
    final base = _h3.getRes0Cells();
    if (resolution == 0) {
      return base.map((b) => b.toInt()).toList(growable: false);
    }
    final out = <HexIndex>[];
    for (final cell in base) {
      for (final child in _h3.cellToChildren(cell, resolution)) {
        out.add(child.toInt());
      }
    }
    return out;
  }
}
