import '../../../../core/hex/hex_index.dart';

abstract interface class IProgressRepository {
  /// Returns every explored cell at [kHexStorageResolution]. Empty on first
  /// launch.
  Set<HexIndex> load();

  /// Replaces the persisted set with [cells].
  Future<void> save(Set<HexIndex> cells);
}
