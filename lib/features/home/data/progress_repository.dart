import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/hex/hex_index.dart';
import '../domain/repositories/i_progress_repository.dart';

@Singleton(as: IProgressRepository)
class ProgressRepository implements IProgressRepository {
  ProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Set<HexIndex> load() {
    final raw = _prefs.getString(kCellsStorageKey);
    if (raw == null) return <HexIndex>{};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<num>().map((n) => n.toInt()).toSet();
    } on Exception {
      return <HexIndex>{};
    }
  }

  @override
  Future<void> save(Set<HexIndex> cells) {
    return _prefs.setString(
      kCellsStorageKey,
      jsonEncode(cells.toList(growable: false)),
    );
  }
}
