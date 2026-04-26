import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/design_tokens.dart';

/// Initial screen shown for [_kSplashDuration] before navigating to
/// `/home`. Replicates the splash artboard from the design hand-off
/// (`new_design/Obscuro Map Design.html` → `SplashScreen`):
///
///   * dark 168° gradient background with a sparse hex watermark
///   * radial purple glow behind the logo
///   * custom pin logo with internal hex texture, shine, drop-shadow
///   * "OBSCURO MAP" / "Explore the unknown" in Cinzel
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> {
  static const Duration _kSplashDuration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    Future.delayed(_kSplashDuration, () {
      if (!mounted) return;
      context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient — matches the design's
          // linear-gradient(168deg, #13101F 0%, #0D0B18 55%, #111626 100%).
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0.21, -1.0), // 168° in CSS ≈ this in Flutter
                end: Alignment(-0.21, 1.0),
                colors: [
                  Color(0xFF13101F),
                  Color(0xFF0D0B18),
                  Color(0xFF111626),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Hex watermark — sparse hex grid at 5.8 % opacity.
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HexWatermarkPainter(),
              ),
            ),
          ),
          // Radial glow behind the pin (380×380, slightly above centre).
          const _RadialGlow(),
          // Centred logo + name + tagline.
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PinLogo(),
                const SizedBox(height: 34),
                Text(
                  'OBSCURO MAP',
                  style: GoogleFonts.cinzel(
                    color: kColorPurpleLight,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 26 * 0.14,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'EXPLORE THE UNKNOWN',
                  style: GoogleFonts.cinzel(
                    color: const Color.fromRGBO(193, 189, 210, 0.38),
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 10 * 0.38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGlow extends StatelessWidget {
  const _RadialGlow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final cx = constraints.maxWidth / 2;
        final cy = constraints.maxHeight / 2;
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                // CSS translate(-50%, -60%) → glow centre 60 % of glow-height
                // above the screen centre, so the offset is glowSize/2 +
                // glowSize/10.
                left: cx - 190,
                top: cy - 190 - 380 * 0.10,
                width: 380,
                height: 380,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      radius: 0.5,
                      colors: [
                        Color.fromRGBO(107, 90, 155, 0.14),
                        Color.fromRGBO(107, 90, 155, 0.0),
                      ],
                      stops: [0.0, 0.7],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PinLogo extends StatelessWidget {
  const _PinLogo();

  @override
  Widget build(BuildContext context) {
    // Outer container carries the drop-shadow per the spec.
    return SizedBox(
      width: 118,
      height: 140,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(107, 90, 155, 0.42),
              offset: Offset(0, 10),
              blurRadius: 36,
            ),
          ],
        ),
        child: CustomPaint(painter: _PinPainter()),
      ),
    );
  }
}

/// Pin logo painter. ViewBox semantics from the design HTML
/// (`viewBox="-59 -58 118 136"`): origin (0, 0) sits roughly at the pin's
/// centroid; the pin path extends from y = -50 (top of head) to y = 66
/// (tip).
class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, 58); // map (0,0) to viewBox origin

    // Pin silhouette path.
    final pin = Path()
      ..moveTo(0, -50)
      ..cubicTo(-35, -50, -50, -28, -50, -4)
      ..cubicTo(-50, 22, -20, 46, 0, 66)
      ..cubicTo(20, 46, 50, 22, 50, -4)
      ..cubicTo(50, -28, 35, -50, 0, -50)
      ..close();

    // Body fill: linear gradient #9B8EC4 → #3D3360, top-left → bottom-right.
    final bodyRect = pin.getBounds();
    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9B8EC4), kColorPurpleDeeper],
      ).createShader(bodyRect);
    canvas.drawPath(pin, body);

    // Inner hex texture (clipped to pin shape, opacity 0.42).
    canvas.save();
    canvas.clipPath(pin);
    final texturePaint = Paint()
      ..color = const Color.fromRGBO(193, 189, 210, 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const texturePositions = [
      Offset(-20, -32),
      Offset(4, -32),
      Offset(28, -32),
      Offset(-8, -12),
      Offset(16, -12),
      Offset(4, 8),
      Offset(-20, 8),
    ];
    for (final p in texturePositions) {
      canvas.drawPath(_hex(p, 16), texturePaint);
    }
    canvas.restore();

    // Shine layer (radial highlight at upper-left).
    final shineRect = Rect.fromCircle(
      center: Offset(bodyRect.left + bodyRect.width * 0.35,
          bodyRect.top + bodyRect.height * 0.28),
      radius: bodyRect.width * 0.55,
    );
    final shine = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color.fromRGBO(255, 255, 255, 0.20),
          Color.fromRGBO(255, 255, 255, 0.0),
        ],
        stops: [0.0, 1.0],
      ).createShader(shineRect);
    canvas.drawPath(pin, shine);

    // Inner dark circle.
    canvas.drawCircle(
      const Offset(0, -4),
      16,
      Paint()..color = const Color.fromRGBO(11, 8, 20, 0.58),
    );
    // Tiny lavender dot inside the circle.
    canvas.drawCircle(
      const Offset(0, -4),
      6,
      Paint()..color = const Color.fromRGBO(193, 189, 210, 0.22),
    );
  }

  /// Flat-top hexagon centred on [c] with circumradius [r] (matches the
  /// design's `hexPoints` helper).
  Path _hex(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 3 * i;
      final x = c.dx + r * math.cos(a);
      final y = c.dy + r * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_PinPainter oldDelegate) => false;
}

class _HexWatermarkPainter extends CustomPainter {
  const _HexWatermarkPainter();

  // Spec: circumradius 58, flat-top, stroke #C1BDD2, layer opacity 0.058,
  // stroke alpha 0.9. We bake the layer-opacity into the stroke colour
  // (saves a saveLayer per frame — splash paints once anyway).
  static const double _r = 58;
  static const double _strokeWidth = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final hexHeight = math.sqrt(3) * _r;
    final colStep = _r * 1.5;

    final paint = Paint()
      ..color = const Color.fromRGBO(193, 189, 210, 0.058)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    // Match the React reference: walk col/row indices that span the
    // viewport with one cell of slack so edges aren't clipped.
    final cols = (w / colStep).ceil() + 2;
    final rows = (h / hexHeight).ceil() + 2;
    for (var c = -1; c < cols; c++) {
      for (var r = -1; r < rows; r++) {
        final cx = _r + c * colStep;
        final cy = hexHeight / 2 + r * hexHeight + (c.isOdd ? hexHeight / 2 : 0);
        canvas.drawPath(_hexPath(Offset(cx, cy), _r - 1.5), paint);
      }
    }
  }

  Path _hexPath(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = math.pi / 3 * i;
      final x = c.dx + r * math.cos(a);
      final y = c.dy + r * math.sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_HexWatermarkPainter oldDelegate) => false;
}
