import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../core/constants/map_constants.dart';
import '../../../core/services/foreground_service.dart';
import '../domain/repositories/i_progress_repository.dart';
import '../domain/usecases/append_track_point_usecase.dart';
import '../domain/usecases/erase_points_usecase.dart';
import 'location_event.dart';
import 'location_state.dart';

@injectable
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  LocationBloc(
    this._repository,
    this._appendTrackPoint,
    this._erasePoints,
  ) : super(const LocationInitial()) {
    on<LocationStarted>(_onStarted);
    on<LocationPointsErased>(_onPointsErased);
    on<LocationProgressSaved>(_onProgressSaved);
    on<LocationAreaFilled>(_onAreaFilled);
  }

  final IProgressRepository _repository;
  final AppendTrackPointUseCase _appendTrackPoint;
  final ErasePointsUseCase _erasePoints;

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

    emit(LocationTracking(
      List.unmodifiable(_repository.load()),
      fillPoints: List.unmodifiable(_repository.loadFill()),
    ));

    try {
      await emit.forEach<Position>(
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: kLocationDistanceFilterMeters,
          ),
        ),
        onData: (position) {
          final current = state;
          if (current is! LocationTracking) return state;

          final incoming = LatLng(position.latitude, position.longitude);
          final next = _appendTrackPoint(current.points, incoming);
          if (next == null) return current; // below movement threshold

          final unmodifiable = List<LatLng>.unmodifiable(next);
          _repository.save(unmodifiable).ignore();
          return LocationTracking(unmodifiable, fillPoints: current.fillPoints);
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
    final result = _erasePoints(
      points: current.points,
      fillPoints: current.fillPoints,
      center: event.center,
      radiusMeters: event.radiusMeters,
    );
    emit(LocationTracking(
      List.unmodifiable(result.points),
      fillPoints: List.unmodifiable(result.fillPoints),
    ));
    // Caller dispatches LocationProgressSaved when the gesture ends.
  }

  Future<void> _onProgressSaved(
    LocationProgressSaved event,
    Emitter<LocationState> emit,
  ) async {
    final current = state;
    if (current is! LocationTracking) return;
    await Future.wait([
      _repository.save(current.points),
      _repository.saveFill(current.fillPoints),
    ]);
  }

  void _onAreaFilled(LocationAreaFilled event, Emitter<LocationState> emit) {
    final current = state;
    if (current is! LocationTracking) return;
    final next = LocationTracking(
      current.points,
      fillPoints:
          List.unmodifiable([...current.fillPoints, ...event.fillPoints]),
    );
    _repository.saveFill(next.fillPoints).ignore();
    emit(next);
  }
}
