import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../core/constants/firestore_keys.dart';
import '../../../core/hex/h3_service.dart';
import '../../../core/hex/hex_index.dart';
import '../domain/entities/remote_progress.dart';
import '../domain/repositories/i_remote_progress_repository.dart';

@Singleton(as: IRemoteProgressRepository)
class FirestoreProgressRepository implements IRemoteProgressRepository {
  FirestoreProgressRepository(this._h3);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final H3Service _h3;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(kUsersCollection).doc(uid);

  @override
  Future<RemoteProgress?> load(String uid) async {
    final snap = await _userDoc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;

    final cells = _decodeCells(data[kFieldCells]);

    // Legacy v1 docs only ever had `points` / `fillPoints` (lists of
    // GeoPoint). On first read by a v2 client we promote them to cells —
    // the next save() then writes `cells` and the legacy fields will be
    // overwritten/dropped at that point.
    _ingestLegacyGeoPoints(data[kLegacyFieldPoints], cells);
    _ingestLegacyGeoPoints(data[kLegacyFieldFillPoints], cells);

    return RemoteProgress(cells: cells);
  }

  @override
  Future<void> save(String uid, {required Set<HexIndex> cells}) {
    return _userDoc(uid).set({
      kFieldCells: cells.toList(growable: false),
      kFieldUpdatedAt: FieldValue.serverTimestamp(),
      kFieldSchemaVersion: kProgressSchemaVersion,
    });
  }

  static Set<HexIndex> _decodeCells(Object? raw) {
    if (raw is! List) return <HexIndex>{};
    final out = <HexIndex>{};
    for (final item in raw) {
      if (item is int) {
        out.add(item);
      } else if (item is num) {
        out.add(item.toInt());
      }
    }
    return out;
  }

  void _ingestLegacyGeoPoints(Object? raw, Set<HexIndex> into) {
    if (raw is! List) return;
    for (final item in raw) {
      if (item is GeoPoint) {
        into.add(_h3.latLngToCell(
          LatLng(item.latitude, item.longitude),
          kHexStorageResolution,
        ));
      }
    }
  }
}
