import 'package:google_maps_flutter/google_maps_flutter.dart';

// Default camera target — central Kyiv. Used until the first GPS fix arrives.
const kInitialCameraTarget = LatLng(50.4501, 30.5234);
const kInitialCameraZoom = 13.0;

// Zoom 16.5 yields roughly a 400 m wide visible area on a typical
// ~400 dp-wide phone at mid latitudes (156543·cos(lat)/2^16.5 m per dp).
// Applied only on the initial auto-center; the recenter button keeps the
// user's current zoom.
const kInitialUserZoom = 16.5;

const kEraserRadiusMeters = 30.0;

const kMetersPerDegreeLat = 110540.0;
const kMetersPerDegreeLngEquator = 111320.0;

const kEarthRadiusMeters = 6371000.0;

// OS-level pre-filter: drop GPS updates closer than this to the previous one.
// At storage resolution (H3 res 11, ~25 m edge) we want a sample density
// fine enough that consecutive fixes rarely skip more than one cell — but
// the use case interpolates via h3.cellsAlongPath when they do, so this is
// a quality-of-data filter rather than a correctness one.
const kLocationDistanceFilterMeters = 5;

// Hex-grid outline widths. Colours come from `design_tokens.dart` —
// `kColorExploredHexOutline` (alpha 0.28) and `kColorUnexploredHexOutline`
// (alpha 0.15) — so the look matches the Obscuro Map handoff.
const kHexOutlineWidth = 1.0;
const kHexGridOverlayWidth = 1.0;
