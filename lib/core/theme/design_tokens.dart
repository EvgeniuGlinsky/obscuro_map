import 'package:flutter/material.dart';

/// Design tokens from the Claude Design hand-off (`lib/new_design/README.md`).
///
/// Colours, opacities and typography in one place so the look stays
/// coordinated across screens. Geometry tokens (button sizes, paddings)
/// also live here even when they shadow individual constants in
/// `ui_constants.dart` — the latter is gradually being absorbed into this
/// file as the new visual is rolled out.

// ── Brand palette ─────────────────────────────────────────────────────

const kColorDeepDark = Color(0xFF0D0B18);
const kColorTextDark = Color(0xFF18142A);
const kColorPurpleLight = Color(0xFFC1BDD2);
const kColorPurpleMid = Color(0xFF9D8FCC);
const kColorPurpleButtonStart = Color(0xFF8B7FAA);
const kColorPurpleButtonEnd = Color(0xFF5B4E8A);
const kColorPurpleDeep = Color(0xFF4A3F6B);
const kColorPurpleDeeper = Color(0xFF3D3360);

// ── Fog ───────────────────────────────────────────────────────────────
//
// rgba(18,12,38,0.72). Replaces the legacy `kFogColor` defined as
// black @ 0.72 — the new palette has a violet undertone that reads as
// "magic mist" rather than "dark overlay".

const kColorFog = Color.fromRGBO(18, 12, 38, 0.72);

// ── Hex grid outlines ─────────────────────────────────────────────────

/// Outline drawn on top of *explored* cells. `rgba(193,189,210,0.28)`.
const kColorExploredHexOutline = Color.fromRGBO(193, 189, 210, 0.28);

/// Reference grid drawn over *unexplored* fog. `rgba(193,189,210,0.15)`.
const kColorUnexploredHexOutline = Color.fromRGBO(193, 189, 210, 0.15);

// ── Map control buttons ───────────────────────────────────────────────

const double kMapButtonSize = 48.0;
const double kMapButtonRadius = 24.0;
const double kMapButtonGap = 9.0;
const double kMapButtonRightInset = 14.0;

const Color kMapButtonInactiveBg = Color.fromRGBO(255, 255, 255, 0.94);
const Color kMapButtonInactiveBorder = Color.fromRGBO(255, 255, 255, 0.55);
const Color kMapButtonInactiveIcon = kColorTextDark;

const LinearGradient kMapButtonActiveGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kColorPurpleButtonStart, kColorPurpleButtonEnd],
);
const Color kMapButtonActiveBorder = Color.fromRGBO(193, 189, 210, 0.30);
const Color kMapButtonActiveIcon = Color.fromRGBO(255, 255, 255, 0.97);

const List<BoxShadow> kMapButtonInactiveShadow = [
  BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.44),
    offset: Offset(0, 4),
    blurRadius: 20,
  ),
  BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.28),
    offset: Offset(0, 2),
    blurRadius: 8,
  ),
];

const List<BoxShadow> kMapButtonActiveShadow = [
  BoxShadow(
    color: Color.fromRGBO(107, 90, 155, 0.60),
    offset: Offset(0, 4),
    blurRadius: 20,
  ),
  BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.50),
    offset: Offset(0, 2),
    blurRadius: 8,
  ),
];

// ── Sign-in pill ──────────────────────────────────────────────────────

const Color kSignInPillBg = Color.fromRGBO(255, 255, 255, 0.97);
const Color kSignInPillBorder = Color.fromRGBO(255, 255, 255, 0.45);
const double kSignInPillTopOffset = 66.0;
const EdgeInsets kSignInPillPadding =
    EdgeInsets.symmetric(horizontal: 20, vertical: 10);

const List<BoxShadow> kSignInPillShadow = [
  BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.48),
    offset: Offset(0, 4),
    blurRadius: 24,
  ),
  BoxShadow(
    color: Color.fromRGBO(0, 0, 0, 0.20),
    offset: Offset(0, 1),
    blurRadius: 4,
  ),
];
