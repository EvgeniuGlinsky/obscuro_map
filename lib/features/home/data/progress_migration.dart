import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/hex/h3_service.dart';
import '../../../core/hex/hex_index.dart';

/// One-shot v1 → v2 schema migration for *local* data.
///
/// v1 stored two JSON arrays of `{lat, lng}` objects under
/// `fog_progress_v1` / `fog_fill_v1`. v2 stores a single JSON array of H3
/// cell ints under `fog_cells_v2`.
///
/// Strategy: read both legacy arrays, map every point to its res-11 cell
/// (idempotent on re-runs), union into the existing v2 set, persist, then
/// delete the legacy keys so the migration is genuinely one-shot.
///
/// Cloud data is migrated separately by [SyncProgressOnLoginUseCase] when
/// the user signs in.
@lazySingleton
class ProgressMigration {
  ProgressMigration(this._h3);

  final H3Service _h3;

  Future<void> migrateLocalIfNeeded(SharedPreferences prefs) async {
    final hadLegacy = prefs.containsKey(kLegacyProgressStorageKey) ||
        prefs.containsKey(kLegacyFillStorageKey);
    if (!hadLegacy) return;

    final cells = <HexIndex>{};

    // Existing v2 data takes precedence and is preserved.
    final existing = prefs.getString(kCellsStorageKey);
    if (existing != null) {
      try {
        for (final n in (jsonDecode(existing) as List<dynamic>).cast<num>()) {
          cells.add(n.toInt());
        }
      } on Exception {
        // Corrupt v2 — drop it. Re-derive from v1.
      }
    }

    _ingestLegacyKey(prefs, kLegacyProgressStorageKey, cells);
    _ingestLegacyKey(prefs, kLegacyFillStorageKey, cells);

    await prefs.setString(
      kCellsStorageKey,
      jsonEncode(cells.toList(growable: false)),
    );
    await prefs.remove(kLegacyProgressStorageKey);
    await prefs.remove(kLegacyFillStorageKey);
  }

  void _ingestLegacyKey(
    SharedPreferences prefs,
    String key,
    Set<HexIndex> into,
  ) {
    final raw = prefs.getString(key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final entry in list) {
        final lat = entry['lat'];
        final lng = entry['lng'];
        if (lat is! num || lng is! num) continue;
        into.add(_h3.latLngToCell(
          LatLng(lat.toDouble(), lng.toDouble()),
          kHexStorageResolution,
        ));
      }
    } on Exception {
      // Corrupt legacy blob — drop it. The user agreed to destructive
      // migration semantics.
    }
  }

  /// Migrates a Firestore document whose v1 fields (`points`, `fillPoints`)
  /// were left in place by an older client. Returns the union of the
  /// existing v2 cell set and the converted legacy points.
  Set<HexIndex> migrateRemoteDoc(Map<String, dynamic> data) {
    final cells = <HexIndex>{};

    final v2 = data[_kFieldCells];
    if (v2 is List) {
      for (final item in v2) {
        if (item is num) cells.add(item.toInt());
      }
    }

    _ingestRemoteList(data[_kLegacyFieldPoints], cells);
    _ingestRemoteList(data[_kLegacyFieldFillPoints], cells);

    return cells;
  }

  void _ingestRemoteList(Object? raw, Set<HexIndex> into) {
    if (raw is! List) return;
    for (final item in raw) {
      // Firestore native GeoPoint or plain map fallback.
      double? lat;
      double? lng;
      if (item is Map) {
        lat = (item['latitude'] ?? item['lat']) as double?;
        lng = (item['longitude'] ?? item['lng']) as double?;
      } else {
        // GeoPoint instance — accessed via dynamic to avoid a hard import
        // dependency in this domain-adjacent file.
        try {
          final dyn = item as dynamic;
          lat = dyn.latitude as double?;
          lng = dyn.longitude as double?;
        } on Object {
          continue;
        }
      }
      if (lat == null || lng == null) continue;
      into.add(_h3.latLngToCell(
        LatLng(lat, lng),
        kHexStorageResolution,
      ));
    }
  }

  // String literals duplicated locally to avoid the migration importing
  // the schema-key constants module (which advertises only v2 fields).
  static const _kFieldCells = 'cells';
  static const _kLegacyFieldPoints = 'points';
  static const _kLegacyFieldFillPoints = 'fillPoints';
}
