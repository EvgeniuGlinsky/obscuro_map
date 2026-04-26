import '../../../../core/hex/hex_index.dart';

/// Snapshot of a user's progress as stored in Firestore.
class RemoteProgress {
  const RemoteProgress({required this.cells});

  final Set<HexIndex> cells;

  bool get isEmpty => cells.isEmpty;
}
