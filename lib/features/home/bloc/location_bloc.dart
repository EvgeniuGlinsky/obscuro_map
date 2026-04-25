import 'dart:math';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../core/services/foreground_service.dart';
import '../domain/usecases/load_fill_usecase.dart';
import '../domain/usecases/load_progress_usecase.dart';
import '../domain/usecases/save_fill_usecase.dart';
import '../domain/usecases/save_progress_usecase.dart';
import 'location_event.dart';
import 'location_state.dart';

@injectable
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  LocationBloc(
    this._loadProgress,
    this._saveProgress,
    this._loadFill,
    this._saveFill,
  ) : super(const LocationInitial()) {
    on<LocationStarted>(_onStarted);
    on<LocationPointsErased>(_onPointsErased);
    on<LocationProgressSaved>(_onProgressSaved);
    on<LocationAreaFilled>(_onAreaFilled);
  }

  final LoadProgressUseCase _loadProgress;
  final SaveProgressUseCase _saveProgress;
  final LoadFillUseCase _loadFill;
  final SaveFillUseCase _saveFill;

  Future<void> _onStarted(
    LocationStarted event,
    Emitter<LocationState> emit,
  ) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        FirebaseCrashlytics.instance.log(
          'Location permission denied: $permission',
        );
        emit(const LocationPermissionDenied());
        return;
      }
    } on Exception catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Failed to check/request location permission',
      );
      emit(const LocationPermissionDenied());
      return;
    }

    await ForegroundService.startService();

    final saved = _loadProgress();
    final savedFill = _loadFill();
    emit(LocationTracking(
      List.unmodifiable(saved),
      fillPoints: List.unmodifiable(savedFill),
    ));

    try {
    await emit.forEach<Position>(
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          // OS-level pre-filter: skip updates shorter than 2 m.
          distanceFilter: 2,
        ),
      ),
      onData: (position) {
        final current = state;
        if (current is! LocationTracking) return state;

        final incoming = LatLng(position.latitude, position.longitude);
        final pts = current.points;

        // Haversine guard: only persist if the user moved ≥ 2.5 m.
        if (pts.isNotEmpty && _haversine(pts.last, incoming) < 2.5) {
          return current; // same reference → bloc skips re-emission
        }

        // Append then re-simplify. RDP always keeps endpoints, so pts.last
        // (the previous GPS fix) is preserved across rounds.
        final next = List<LatLng>.unmodifiable(
          _simplifyTrack([...pts, incoming]),
        );
        _saveProgress(next).ignore(); // fire-and-forget; no await needed
        return LocationTracking(next);
      },
      onError: (error, stack) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          reason: 'Location stream error',
        );
        return state;
      },
    );
    } finally {
      await ForegroundService.stopService();
    }
  }

  void _onPointsErased(LocationPointsErased event, Emitter<LocationState> emit) {
    final current = state;
    if (current is! LocationTracking) return;
    final filtered = current.points
        .where((p) => _haversine(p, event.center) > event.radiusMeters)
        .toList(growable: false);
    final filteredFill = current.fillPoints
        .where((p) => _haversine(p, event.center) > event.radiusMeters)
        .toList(growable: false);
    emit(LocationTracking(
      List.unmodifiable(filtered),
      fillPoints: List.unmodifiable(filteredFill),
    ));
    // No save here — caller dispatches LocationProgressSaved when done.
  }

  Future<void> _onProgressSaved(
    LocationProgressSaved event,
    Emitter<LocationState> emit,
  ) async {
    final current = state;
    if (current is! LocationTracking) return;
    await Future.wait([
      _saveProgress(current.points),
      _saveFill(current.fillPoints),
    ]);
  }

  void _onAreaFilled(LocationAreaFilled event, Emitter<LocationState> emit) {
    final current = state;
    if (current is! LocationTracking) return;
    final next = LocationTracking(
      current.points,
      fillPoints: List.unmodifiable([...current.fillPoints, ...event.fillPoints]),
    );
    _saveFill(next.fillPoints).ignore();
    emit(next);
  }

  static double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final sinDLat = sin(dLat / 2);
    final sinDLon = sin(dLon / 2);
    final h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon;
    return 2 * r * atan2(sqrt(h), sqrt(1 - h));
  }
}

// ---------------------------------------------------------------------------
// Ramer–Douglas–Peucker track simplification
// ---------------------------------------------------------------------------

// Maximum allowable cross-track error. Must stay below the painter's reveal
// radius (15 m) so that removing a point never creates a visible fog gap.
const _rdpEpsilonMeters = 5.0;

/// Reduces [pts] to the smallest subset that lies within [_rdpEpsilonMeters]
/// of the original polyline. Uses an iterative stack to avoid recursion limits
/// on very long tracks.
List<LatLng> _simplifyTrack(List<LatLng> pts) {
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
      final d = _crossTrackMeters(pts[i], pts[start], pts[end]);
      if (d > maxDist) {
        maxDist = d;
        maxIdx = i;
      }
    }

    if (maxDist >= _rdpEpsilonMeters) {
      keep[maxIdx] = true;
      stack.add((start, maxIdx));
      stack.add((maxIdx, end));
    }
  }

  return [for (var i = 0; i < pts.length; i++) if (keep[i]) pts[i]];
}

/// Perpendicular distance in metres from [p] to segment [a]→[b].
/// Uses equirectangular projection — accurate to <0.1 % for segments < 100 km,
/// which covers all realistic GPS tracks.
double _crossTrackMeters(LatLng p, LatLng a, LatLng b) {
  const r = 6371000.0;
  const toRad = pi / 180.0;
  final k = cos((a.latitude + b.latitude) / 2 * toRad);

  final ax = a.longitude * toRad * k, ay = a.latitude * toRad;
  final bx = b.longitude * toRad * k, by = b.latitude * toRad;
  final px = p.longitude * toRad * k, py = p.latitude * toRad;

  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0.0) {
    final ex = px - ax, ey = py - ay;
    return sqrt(ex * ex + ey * ey) * r;
  }
  return ((dx * (ay - py) - dy * (ax - px)).abs() / sqrt(len2)) * r;
}
