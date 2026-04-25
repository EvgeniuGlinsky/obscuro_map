import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';

import '../../../core/constants/firestore_keys.dart';
import '../domain/entities/remote_progress.dart';
import '../domain/repositories/i_remote_progress_repository.dart';

@Singleton(as: IRemoteProgressRepository)
class FirestoreProgressRepository implements IRemoteProgressRepository {
  FirestoreProgressRepository();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(kUsersCollection).doc(uid);

  @override
  Future<RemoteProgress?> load(String uid) async {
    final snap = await _userDoc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return RemoteProgress(
      points: _decodePoints(data[kFieldPoints]),
      fillPoints: _decodePoints(data[kFieldFillPoints]),
    );
  }

  @override
  Future<void> save(
    String uid, {
    required List<LatLng> points,
    required List<LatLng> fillPoints,
  }) {
    return _userDoc(uid).set({
      kFieldPoints: points.map(_toGeoPoint).toList(growable: false),
      kFieldFillPoints: fillPoints.map(_toGeoPoint).toList(growable: false),
      kFieldUpdatedAt: FieldValue.serverTimestamp(),
      kFieldSchemaVersion: kProgressSchemaVersion,
    });
  }

  static GeoPoint _toGeoPoint(LatLng p) => GeoPoint(p.latitude, p.longitude);

  static List<LatLng> _decodePoints(Object? raw) {
    if (raw is! List) return const [];
    final out = <LatLng>[];
    for (final item in raw) {
      if (item is GeoPoint) {
        out.add(LatLng(item.latitude, item.longitude));
      }
    }
    return out;
  }
}
