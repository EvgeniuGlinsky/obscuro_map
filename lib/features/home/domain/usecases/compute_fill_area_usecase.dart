import 'dart:math';
import 'dart:typed_data';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/map_constants.dart';

sealed class FillResult {
  const FillResult();
}

final class FillSuccess extends FillResult {
  const FillSuccess(this.points);
  final List<LatLng> points;
}

final class FillNotEnclosed extends FillResult {
  const FillNotEnclosed();
}

final class FillTooLarge extends FillResult {
  const FillTooLarge();
}

/// Decides whether a tap is inside an area enclosed by the user's track and,
/// if so, materialises the enclosed region as a list of virtual fill points.
///
/// Pure domain rule: the painter and erase/fill UI both treat track points as
/// "walls" of revealed fog; this use-case BFS-floods cells from the seed and
/// reports one of three outcomes:
///   * [FillSuccess] — enclosed; returns one LatLng per visited grid cell.
///   * [FillNotEnclosed] — flood reached the search boundary.
///   * [FillTooLarge] — visited cells exceeded the [kFillMaxCells] budget.
@lazySingleton
class ComputeFillAreaUseCase {
  const ComputeFillAreaUseCase();

  FillResult call(LatLng seed, List<LatLng> trackPoints) {
    // Equirectangular approximation — accurate to <0.1 % within 100 km.
    final lngM = kMetersPerDegreeLngEquator * cos(seed.latitude * pi / 180.0);

    final tpx = Float64List(trackPoints.length);
    final tpy = Float64List(trackPoints.length);
    for (var k = 0; k < trackPoints.length; k++) {
      tpx[k] = (trackPoints[k].longitude - seed.longitude) * lngM;
      tpy[k] = (trackPoints[k].latitude - seed.latitude) * kMetersPerDegreeLat;
    }

    const wallCells = kFillWallRadiusMeters ~/ kFillCellMeters + 1;
    const wallR2 = kFillWallRadiusMeters * kFillWallRadiusMeters;
    final walls = <(int, int)>{};
    for (var k = 0; k < trackPoints.length; k++) {
      final ci = (tpx[k] / kFillCellMeters).round();
      final cj = (tpy[k] / kFillCellMeters).round();
      if (ci.abs() > kFillBoundary + wallCells ||
          cj.abs() > kFillBoundary + wallCells) {
        continue;
      }
      for (var di = -wallCells; di <= wallCells; di++) {
        for (var dj = -wallCells; dj <= wallCells; dj++) {
          final dx = (ci + di) * kFillCellMeters - tpx[k];
          final dy = (cj + dj) * kFillCellMeters - tpy[k];
          if (dx * dx + dy * dy <= wallR2) walls.add((ci + di, cj + dj));
        }
      }
    }

    if (walls.contains((0, 0))) return const FillNotEnclosed();

    final visited = <(int, int)>{};
    final queue = <(int, int)>[(0, 0)];
    var head = 0;

    while (head < queue.length) {
      final cell = queue[head++];
      final (i, j) = cell;
      if (!visited.add(cell)) continue;

      if (i.abs() >= kFillBoundary || j.abs() >= kFillBoundary) {
        return const FillNotEnclosed();
      }

      if (visited.length > kFillMaxCells) return const FillTooLarge();

      for (final n in [(i - 1, j), (i + 1, j), (i, j - 1), (i, j + 1)]) {
        if (!visited.contains(n) && !walls.contains(n)) queue.add(n);
      }
    }

    final pts = <LatLng>[];
    for (final (i, j) in visited) {
      pts.add(LatLng(
        seed.latitude + j * kFillCellMeters / kMetersPerDegreeLat,
        seed.longitude + i * kFillCellMeters / lngM,
      ));
    }
    return FillSuccess(pts);
  }
}
