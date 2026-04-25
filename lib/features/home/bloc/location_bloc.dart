import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../core/constants/map_constants.dart';
import '../../../core/services/foreground_service.dart';
import '../../auth/domain/repositories/i_auth_repository.dart';
import '../domain/repositories/i_progress_repository.dart';
import '../domain/repositories/i_remote_progress_repository.dart';
import '../domain/usecases/append_track_point_usecase.dart';
import '../domain/usecases/erase_points_usecase.dart';
import '../domain/usecases/sync_progress_on_login_usecase.dart';
import 'location_event.dart';
import 'location_state.dart';

@injectable
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  LocationBloc(
    this._repository,
    this._appendTrackPoint,
    this._erasePoints,
    this._authRepository,
    this._remoteRepository,
    this._syncProgress,
  ) : super(const LocationInitial()) {
    on<LocationStarted>(_onStarted);
    on<LocationPointsErased>(_onPointsErased);
    on<LocationProgressSaved>(_onProgressSaved);
    on<LocationAreaFilled>(_onAreaFilled);
    on<LocationAuthChanged>(_onAuthChanged);

    _authSub = _authRepository.user
        .map((u) => u?.uid)
        .distinct()
        .listen((uid) => add(LocationAuthChanged(uid)));
    final initialUid = _authRepository.currentUser?.uid;
    if (initialUid != null) _currentUid = initialUid;
  }

  final IProgressRepository _repository;
  final AppendTrackPointUseCase _appendTrackPoint;
  final ErasePointsUseCase _erasePoints;
  final IAuthRepository _authRepository;
  final IRemoteProgressRepository _remoteRepository;
  final SyncProgressOnLoginUseCase _syncProgress;

  StreamSubscription<String?>? _authSub;

  /// `null` while signed out. Saves are mirrored to the cloud only when this
  /// is set.
  String? _currentUid;

  /// Tracks which uid we already synced this session, to keep the round-trip
  /// to a single read+write per sign-in regardless of how many auth events
  /// the stream replays (cold start emits twice on some Firebase versions).
  String? _syncedUid;

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
          if (next == null) return current;

          final unmodifiable = List<LatLng>.unmodifiable(next);
          _repository.save(unmodifiable).ignore();
          _mirrorToRemote(points: unmodifiable, fillPoints: current.fillPoints);
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

  void _onPointsErased(
    LocationPointsErased event,
    Emitter<LocationState> emit,
  ) {
    final current = state;
    if (current is! LocationTracking) return;
    final result = _erasePoints(
      points: current.points,
      fillPoints: current.fillPoints,
      center: event.center,
      radiusMeters: event.radiusMeters,
    );
    final newPoints = List<LatLng>.unmodifiable(result.points);
    final newFill = List<LatLng>.unmodifiable(result.fillPoints);
    emit(LocationTracking(newPoints, fillPoints: newFill));
    // Persist locally on every erase, not just on gesture end. The gesture
    // can be cancelled (pointer leaves the widget, app backgrounded, parent
    // wins arena) without firing onTapUp / onPanEnd, in which case the
    // batched save would never run and the deletion would survive only in
    // memory. Cloud mirror remains debounced via LocationProgressSaved.
    _repository.save(newPoints).ignore();
    _repository.saveFill(newFill).ignore();
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
    _mirrorToRemote(
      points: current.points,
      fillPoints: current.fillPoints,
    );
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
    _mirrorToRemote(points: next.points, fillPoints: next.fillPoints);
    emit(next);
  }

  Future<void> _onAuthChanged(
    LocationAuthChanged event,
    Emitter<LocationState> emit,
  ) async {
    _currentUid = event.uid;
    if (event.uid == null) {
      // Signed out — keep local data, just stop mirroring.
      _syncedUid = null;
      return;
    }
    if (_syncedUid == event.uid) return; // already synced this session
    _syncedUid = event.uid;

    try {
      final result = await _syncProgress(event.uid!);
      switch (result) {
        case SyncUploadedLocal():
          // Local stayed authoritative; nothing to do.
          break;
        case SyncDownloadedRemote(:final points, :final fillPoints):
          // Cloud overwrote local — replace in-memory state.
          emit(LocationTracking(
            List.unmodifiable(points),
            fillPoints: List.unmodifiable(fillPoints),
          ));
          break;
      }
    } on Exception catch (e, st) {
      // Treat sync failure as "act local-only for this session". The next
      // save will retry the cloud write.
      _syncedUid = null;
      await FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Cloud progress sync failed for uid=${event.uid}',
      );
    }
  }

  void _mirrorToRemote({
    required List<LatLng> points,
    required List<LatLng> fillPoints,
  }) {
    final uid = _currentUid;
    if (uid == null) return;
    _remoteRepository.save(uid, points: points, fillPoints: fillPoints).onError(
      (error, stack) => FirebaseCrashlytics.instance.recordError(
        error ?? 'unknown',
        stack,
        reason: 'Mirror to Firestore failed',
      ),
    );
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
