import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../core/constants/map_constants.dart';
import '../../../core/hex/hex_index.dart';
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
    this._eraseCells,
    this._authRepository,
    this._remoteRepository,
    this._syncProgress,
  ) : super(const LocationInitial()) {
    on<LocationStarted>(_onStarted);
    on<LocationCellsErased>(_onCellsErased);
    on<LocationProgressSaved>(_onProgressSaved);
    on<LocationCellsAdded>(_onCellsAdded);
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
  final ErasePointsUseCase _eraseCells;
  final IAuthRepository _authRepository;
  final IRemoteProgressRepository _remoteRepository;
  final SyncProgressOnLoginUseCase _syncProgress;

  StreamSubscription<String?>? _authSub;

  String? _currentUid;
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

    emit(LocationTracking(_repository.load()));

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

          final pos = LatLng(position.latitude, position.longitude);

          // Mutate a fresh set so the previous state's set stays immutable
          // for any listeners still holding it.
          final next = Set<HexIndex>.of(current.cells);
          final update = _appendTrackPoint(
            position: pos,
            previousCell: current.lastCell,
            visited: next,
          );

          if (update.added.isEmpty && current.lastCell == update.currentCell) {
            return current;
          }
          if (update.added.isNotEmpty) {
            _repository.save(next).ignore();
            _mirrorToRemote(next);
          }
          return LocationTracking(next, lastCell: update.currentCell);
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

  void _onCellsErased(
    LocationCellsErased event,
    Emitter<LocationState> emit,
  ) {
    final current = state;
    if (current is! LocationTracking) return;
    final remaining = _eraseCells(
      cells: current.cells,
      center: event.center,
      radiusMeters: event.radiusMeters,
    );
    if (remaining.length == current.cells.length) return;
    emit(LocationTracking(remaining, lastCell: current.lastCell));
    // Persist immediately on every erase. Cloud mirror is debounced via
    // LocationProgressSaved on gesture end.
    _repository.save(remaining).ignore();
  }

  Future<void> _onProgressSaved(
    LocationProgressSaved event,
    Emitter<LocationState> emit,
  ) async {
    final current = state;
    if (current is! LocationTracking) return;
    await _repository.save(current.cells);
    _mirrorToRemote(current.cells);
  }

  void _onCellsAdded(LocationCellsAdded event, Emitter<LocationState> emit) {
    final current = state;
    if (current is! LocationTracking) return;
    final next = Set<HexIndex>.of(current.cells)..addAll(event.cells);
    if (next.length == current.cells.length) return;
    emit(LocationTracking(next, lastCell: current.lastCell));
    _repository.save(next).ignore();
    _mirrorToRemote(next);
  }

  Future<void> _onAuthChanged(
    LocationAuthChanged event,
    Emitter<LocationState> emit,
  ) async {
    _currentUid = event.uid;
    if (event.uid == null) {
      _syncedUid = null;
      return;
    }
    if (_syncedUid == event.uid) return;
    _syncedUid = event.uid;

    try {
      final result = await _syncProgress(event.uid!);
      switch (result) {
        case SyncUploadedLocal():
          break;
        case SyncDownloadedRemote(:final cells):
          final current = state;
          emit(LocationTracking(
            cells,
            lastCell: current is LocationTracking ? current.lastCell : null,
          ));
          break;
      }
    } on Exception catch (e, st) {
      _syncedUid = null;
      await FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Cloud progress sync failed for uid=${event.uid}',
      );
    }
  }

  void _mirrorToRemote(Set<HexIndex> cells) {
    final uid = _currentUid;
    if (uid == null) return;
    _remoteRepository.save(uid, cells: cells).onError(
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
