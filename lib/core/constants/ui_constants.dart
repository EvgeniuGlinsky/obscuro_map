import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

const kSnackBarDuration = Duration(seconds: 4);

// Fog & eraser visuals — re-exported from the new design tokens so all the
// painters keep their existing imports untouched.
const Color kFogColor = kColorFog;

final kEraserOverlayColor = Colors.red.withValues(alpha: 0.25);
const kEraserStrokeColor = Colors.red;
const kEraserStrokeWidth = 2.0;

// Map button geometry. Re-exports from `design_tokens.dart` for back-compat
// with existing references in `home_view.dart`.
const kMapButtonPadding = EdgeInsets.all(12);
const kMapButtonIconSize = 22.0;
const kMapButtonsRightInset = kMapButtonRightInset;
const kMapButtonsBottomInset = 48.0;
const kMapButtonsSpacing = kMapButtonGap;
