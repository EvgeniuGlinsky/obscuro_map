// One-shot rasteriser for the launcher icon.
//
// Run with:
//   flutter test test/tool/generate_launcher_icons_test.dart
//
// Reads `lib/new_design/app icon.svg` and produces, in one go:
//
//   1. `ic_launcher.png` per mipmap density — the legacy fallback icon
//      for pre-Android-8 launchers and any surface that doesn't honour
//      adaptive icons. Solid purple square + scaled pin.
//
//   2. `ic_launcher_foreground.png` per mipmap density — the pin on a
//      transparent canvas, sized for the 108dp adaptive-icon foreground.
//      The matching background is a colour resource (see
//      `res/values/colors.xml` → `ic_launcher_background`); the
//      adaptive-icon XML in `res/mipmap-anydpi-v26/ic_launcher.xml`
//      ties them together.
//
//   3. The 512×512 Play Store icon at
//      `lib/new_design/android_icons/playstore/ic_launcher.png`.
//
// Why the adaptive-icon split matters: on Android 8+, launchers (Pixel,
// Samsung, etc.) treat any flat icon as "legacy" and wrap it in their
// own white circle, leaving our purple square nested inside a white
// halo. Providing a real adaptive icon hands the launcher our purple
// background directly, so the launcher's mask is filled with our
// colour rather than its own white.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _svgPath = 'lib/new_design/app icon.svg';
const _resBase = 'android/app/src/main/res';
const _playStorePath =
    'lib/new_design/android_icons/playstore/ic_launcher.png';

// Standard Android launcher icon sizes per density (legacy: 48dp tile;
// adaptive foreground: 108dp tile).
const Map<String, int> _legacyPx = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192,
};

const Map<String, int> _foregroundPx = {
  'mipmap-mdpi': 108,
  'mipmap-hdpi': 162,
  'mipmap-xhdpi': 216,
  'mipmap-xxhdpi': 324,
  'mipmap-xxxhdpi': 432,
};

const int _playStorePx = 512;

/// Solid background colour for the legacy (flat) icon. Matches the
/// `ic_launcher_background` colour resource so legacy and adaptive
/// renderings look identical.
const Color _iconBackground = Color(0xFFC1BDD2);

/// Centre point of the pin within the source SVG (viewBox 0 0 72 72).
const double _pinCenterX = 36.0;
const double _pinCenterY = 32.2;

/// Pin up-scale on the **legacy** (48dp) icon — it's drawn directly into
/// the visible tile so it can be aggressive and fill the square.
const double _legacyPinScale = 1.55;

/// Pin scale on the **adaptive foreground** (108dp canvas). The
/// launcher's mask trims the canvas to roughly an inner ~72dp circle.
///
/// At 1.0 the pin's height of ~40.6 (in the 72-unit SVG) lands at
/// 60.9dp inside the 108dp canvas. We sit at 0.83 — leaves a generous
/// margin around the pin so the icon reads as a bold logo with breathing
/// room rather than a cramped square.
const double _foregroundPinScale = 0.83;

/// `flutter_svg` (via `vector_graphics_compiler`) treats `stop-color`
/// and `fill` attributes that use the CSS `rgba(r,g,b,a)` form as fully
/// opaque — the alpha channel is silently dropped. The source SVG uses
/// `rgba()` heavily for soft gradient stops and inner-circle fills, so
/// without this rewrite the rendered icon collapses into solid colour
/// blocks.
String _normaliseRgba(String svg) {
  final re = RegExp(
    r'(stop-color|fill)="rgba\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([\d.]+)\s*\)"',
  );
  return svg.replaceAllMapped(re, (m) {
    final attr = m[1]!;
    final r = int.parse(m[2]!).toRadixString(16).padLeft(2, '0');
    final g = int.parse(m[3]!).toRadixString(16).padLeft(2, '0');
    final b = int.parse(m[4]!).toRadixString(16).padLeft(2, '0');
    final a = m[5]!;
    final opacityAttr = attr == 'stop-color' ? 'stop-opacity' : 'fill-opacity';
    return '$attr="#${(r + g + b).toUpperCase()}" $opacityAttr="$a"';
  });
}

void main() {
  test('generate launcher icon PNGs from SVG', () async {
    final raw = await File(_svgPath).readAsString();
    final svg = _normaliseRgba(raw);
    final pictureInfo = await vg.loadPicture(SvgStringLoader(svg), null);

    try {
      final sourceWidth = pictureInfo.size.width; // 72
      final sourceHeight = pictureInfo.size.height; // 72

      Future<void> writePng(int px, String outPath, ui.Image image) async {
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final out = File(outPath);
        await out.create(recursive: true);
        await out.writeAsBytes(byteData!.buffer.asUint8List());
        // ignore: avoid_print
        print('  wrote $outPath  (${px}×$px)');
      }

      Future<void> rasterise({
        required int px,
        required String outPath,
        required Color? background,
        required double pinScale,
      }) async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        if (background != null) {
          canvas.drawRect(
            Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()),
            Paint()..color = background,
          );
        }

        // Centre on the tile, then scale up around the pin's centroid.
        final baseScale = px / sourceWidth;
        final scale = baseScale * pinScale;
        canvas.translate(px / 2, px / 2);
        canvas.scale(scale, scale);
        canvas.translate(-_pinCenterX, -_pinCenterY);
        canvas.drawPicture(pictureInfo.picture);

        final pic = recorder.endRecording();
        final image = await pic.toImage(px, px);
        await writePng(px, outPath, image);
        pic.dispose();
        image.dispose();
        // sourceHeight isn't used after construction but suppress the
        // unused-local linter without dropping the documenting binding.
        // ignore: unused_local_variable
        final _ = sourceHeight;
      }

      // 1. Legacy flat icons (pre-Android-8 fallback).
      for (final entry in _legacyPx.entries) {
        await rasterise(
          px: entry.value,
          outPath: '$_resBase/${entry.key}/ic_launcher.png',
          background: _iconBackground,
          pinScale: _legacyPinScale,
        );
      }

      // 2. Adaptive foreground (transparent — background comes from
      //    @color/ic_launcher_background via the adaptive-icon XML).
      for (final entry in _foregroundPx.entries) {
        await rasterise(
          px: entry.value,
          outPath: '$_resBase/${entry.key}/ic_launcher_foreground.png',
          background: null,
          pinScale: _foregroundPinScale,
        );
      }

      // 3. Play Store icon — same composition as legacy.
      await rasterise(
        px: _playStorePx,
        outPath: _playStorePath,
        background: _iconBackground,
        pinScale: _legacyPinScale,
      );
    } finally {
      pictureInfo.picture.dispose();
    }
  });
}
