import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@singleton
class ProgressRepository {
  ProgressRepository(this._prefs);

  static const _key = 'fog_progress_v1';

  final SharedPreferences _prefs;

  List<LatLng> load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .cast<Map<String, dynamic>>()
          .map((e) => LatLng(e['lat'] as double, e['lng'] as double))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<LatLng> points) {
    return _prefs.setString(
      _key,
      jsonEncode(
        points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
      ),
    );
  }
}