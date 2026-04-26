// SharedPreferences keys.
//
// `v2` is the H3-cell schema (Set<HexIndex> stored as a JSON int array).
// `v1` keys (`fog_progress_v1`, `fog_fill_v1`) hold the legacy lat/lng-list
// schema and are read once by the v1→v2 migration in
// `progress_migration.dart`, then deleted.
const kCellsStorageKey = 'fog_cells_v2';

// Legacy keys — preserved as constants only so the migration can target
// them. Do not write to these.
const kLegacyProgressStorageKey = 'fog_progress_v1';
const kLegacyFillStorageKey = 'fog_fill_v1';
