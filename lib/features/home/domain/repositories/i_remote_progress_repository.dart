import '../../../../core/hex/hex_index.dart';
import '../entities/remote_progress.dart';

abstract interface class IRemoteProgressRepository {
  /// Returns the cloud-side progress for [uid], or `null` when no document
  /// exists yet (first-time sign-in).
  Future<RemoteProgress?> load(String uid);

  /// Writes the full cell set to the user's document. Existing data is
  /// replaced (last-write-wins).
  Future<void> save(String uid, {required Set<HexIndex> cells});
}
