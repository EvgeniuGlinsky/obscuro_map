import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../repositories/i_progress_repository.dart';
import '../repositories/i_remote_progress_repository.dart';

/// Outcome of [SyncProgressOnLoginUseCase].
sealed class SyncProgressResult {
  const SyncProgressResult();
}

/// Cloud was empty — local was uploaded as the canonical snapshot. The
/// caller should keep its current in-memory state.
final class SyncUploadedLocal extends SyncProgressResult {
  const SyncUploadedLocal();
}

/// Cloud already had data — local was overwritten. The caller must replace
/// its in-memory state with [points] / [fillPoints].
final class SyncDownloadedRemote extends SyncProgressResult {
  const SyncDownloadedRemote({
    required this.points,
    required this.fillPoints,
  });
  final List<LatLng> points;
  final List<LatLng> fillPoints;
}

/// Resolves "first-time login vs returning login" for a freshly authenticated
/// user. Encapsulates the decision so the bloc only reacts to the result.
@lazySingleton
class SyncProgressOnLoginUseCase {
  const SyncProgressOnLoginUseCase(this._local, this._remote);

  final IProgressRepository _local;
  final IRemoteProgressRepository _remote;

  Future<SyncProgressResult> call(String uid) async {
    final remote = await _remote.load(uid);
    if (remote == null || remote.isEmpty) {
      // Cloud has nothing — push the user's local progress up so subsequent
      // logins on other devices can pull it back.
      await _remote.save(
        uid,
        points: _local.load(),
        fillPoints: _local.loadFill(),
      );
      return const SyncUploadedLocal();
    }
    // Cloud wins: overwrite local copies and tell the caller to replace its
    // in-memory state.
    await _local.save(remote.points);
    await _local.saveFill(remote.fillPoints);
    return SyncDownloadedRemote(
      points: remote.points,
      fillPoints: remote.fillPoints,
    );
  }
}

