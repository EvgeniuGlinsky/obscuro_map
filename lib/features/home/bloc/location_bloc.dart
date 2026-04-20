import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../repository/progress_repository.dart';
import 'location_event.dart';
import 'location_state.dart';

@injectable
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  LocationBloc(this._repository) : super(const LocationInitial()) {
    on<LocationStarted>(_onStarted);
  }

  final ProgressRepository _repository;

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
        emit(const LocationPermissionDenied());
        return;
      }
    } on Exception {
      emit(const LocationPermissionDenied());
      return;
    }

    final saved = _repository.load();
    emit(LocationTracking(List.unmodifiable(saved)));

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

        final next = List<LatLng>.unmodifiable([...pts, incoming]);
        _repository.save(next).ignore(); // fire-and-forget; no await needed
        return LocationTracking(next);
      },
    );
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