import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/map_constants.dart';
import '../geo/geo_math.dart';

/// Decides whether a new GPS fix should extend the recorded track and, if so,
/// returns the simplified next track. Encapsulates two domain rules:
///
///  1. Min-movement guard — drop fixes closer than [kMinMovementMeters] to the
///     previous point so GPS jitter doesn't pollute the track.
///  2. Ramer–Douglas–Peucker simplification — keep the smallest subset of
///     points whose polyline stays within [kRdpEpsilonMeters] of the original.
@lazySingleton
class AppendTrackPointUseCase {
  const AppendTrackPointUseCase();

  /// Returns the simplified next track, or `null` if [incoming] should be
  /// ignored as below the movement threshold.
  List<LatLng>? call(List<LatLng> current, LatLng incoming) {
    if (current.isNotEmpty &&
        haversineMeters(current.last, incoming) < kMinMovementMeters) {
      return null;
    }
    return _simplify([...current, incoming]);
  }

  /// Iterative RDP. The stack avoids recursion limits on very long tracks.
  static List<LatLng> _simplify(List<LatLng> pts) {
    if (pts.length < 3) return pts;

    final keep = List<bool>.filled(pts.length, false);
    keep[0] = true;
    keep[pts.length - 1] = true;

    final stack = <(int, int)>[(0, pts.length - 1)];
    while (stack.isNotEmpty) {
      final (start, end) = stack.removeLast();
      if (end - start < 2) continue;

      var maxDist = 0.0;
      var maxIdx = start + 1;
      for (var i = start + 1; i < end; i++) {
        final d = crossTrackMeters(pts[i], pts[start], pts[end]);
        if (d > maxDist) {
          maxDist = d;
          maxIdx = i;
        }
      }

      if (maxDist >= kRdpEpsilonMeters) {
        keep[maxIdx] = true;
        stack.add((start, maxIdx));
        stack.add((maxIdx, end));
      }
    }

    return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
  }
}
