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
const kRevealRadiusMeters = 15.0;

// Consecutive simplified points farther apart than this are from different
// recording sessions; bridge them with moveTo rather than lineTo.
const kSegmentGapMeters = 1000.0;

// Flood-fill grid: 5 m per cell → 25 m² per cell → 20 cells max = 500 m².
const kFillCellMeters = 5.0;
const kFillMaxCells = 20;
const kFillWallRadiusMeters = 15.0; // must match kRevealRadiusMeters
const kFillBoundary = 30; // cells from seed before treating as "not enclosed"

const kMetersPerDegreeLat = 110540.0;
const kMetersPerDegreeLngEquator = 111320.0;

const kEarthRadiusMeters = 6371000.0;

// Maximum allowable cross-track error for RDP simplification. Must stay below
// the painter's reveal radius so removing a point never creates a fog gap.
const kRdpEpsilonMeters = 5.0;

// OS-level pre-filter: drop GPS updates closer than this to the previous one.
const kLocationDistanceFilterMeters = 2;

// Haversine guard before persisting: ignore movements smaller than this.
const kMinMovementMeters = 2.5;
