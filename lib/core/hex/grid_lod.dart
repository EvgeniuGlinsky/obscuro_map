// Resolution picker for the *display-only* reference hex grid drawn over
// unexplored fog when the user toggles the grid overlay on.
//
// IMPORTANT: this is for visualisation of the lattice, NOT for aggregating
// stored exploration data. Cleared cells are always rendered at
// `kHexStorageResolution`. Mixing the two is the bug we already fixed —
// keep the concepts separate.
//
// The picker keeps the visible cell count roughly constant (~30–60 across
// the viewport short axis) so the grid stays readable at every zoom. The
// table reaches all the way down to res 0 (122 base cells = 110 hexagons +
// 12 pentagonal holes — the design's top-level partitioning) so a fully
// zoomed-out user actually sees the base layer rather than plateauing at a
// finer resolution.
//
// Cell edge in metres at each H3 resolution (avg):
//   res 11 → ~25 m
//   res 10 → ~66 m
//   res  9 → ~174 m
//   res  8 → ~461 m
//   res  7 → ~1.22 km
//   res  6 → ~3.23 km
//   res  5 → ~8.54 km
//   res  4 → ~22.6 km
//   res  3 → ~59.8 km
//   res  2 → ~158 km
//   res  1 → ~419 km
//   res  0 → ~1108 km   (110 hexagons + 12 pentagons globally)
int pickGridResolution(double cameraZoom) {
  if (cameraZoom >= 19.0) return 11;
  if (cameraZoom >= 17.0) return 10;
  if (cameraZoom >= 15.0) return 9;
  if (cameraZoom >= 13.0) return 8;
  if (cameraZoom >= 11.0) return 7;
  if (cameraZoom >= 9.0) return 6;
  if (cameraZoom >= 7.0) return 5;
  if (cameraZoom >= 5.5) return 4;
  if (cameraZoom >= 4.0) return 3;
  if (cameraZoom >= 2.5) return 2;
  if (cameraZoom >= 1.0) return 1;
  return 0;
}

/// Above this resolution the grid uses `polygonToCells` against the
/// viewport polygon (cells in viewport only, fast). At and below it, the
/// total cell count globally is small enough (≤ 5,882 at res 2) that we
/// enumerate every cell on Earth — which side-steps the failure modes of
/// `polygonToCells` on a viewport that wraps the antimeridian or crosses
/// Mercator's ±85° pole limit (both routinely happen at zoom < 4).
const int kGridGlobalEnumerationMaxResolution = 2;
