import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/repositories/i_progress_repository.dart';

@Singleton(as: IProgressRepository)
class ProgressRepository implements IProgressRepository {
  ProgressRepository(this._prefs);

  static const _key = 'fog_progress_v1';
  static const _fillKey = 'fog_fill_v1';

  final SharedPreferences _prefs;

  @override
  List<LatLng> load() => _decode(_prefs.getString(_key));

  @override
  Future<void> save(List<LatLng> points) =>
      _prefs.setString(_key, _encode(points));

  @override
  List<LatLng> loadFill() => _decode(_prefs.getString(_fillKey));

  @override
  Future<void> saveFill(List<LatLng> fillPoints) =>
      _prefs.setString(_fillKey, _encode(fillPoints));

  static List<LatLng> _decode(String? raw) {
    if (raw == null) return const [];
    try {
      return (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((e) => LatLng(e['lat'] as double, e['lng'] as double))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String _encode(List<LatLng> points) => jsonEncode(
        points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      );
}