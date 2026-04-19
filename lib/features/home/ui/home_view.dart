import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const _initialCamera = CameraPosition(
    target: LatLng(50.4501, 30.5234),
    zoom: 13.0,
  );

  GoogleMapController? _controller;

  // Fog-of-war: set of revealed circle centres + radius (metres).
  // Populate this from your BLoC/provider as the user explores.
  final List<_RevealedArea> _revealed = [];

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialCamera,
          onMapCreated: (c) => _controller = c,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: _FogOfWarPainter(
              revealed: _revealed,
              fogColor: Colors.black.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }
}

class _RevealedArea {
  final Offset center; // widget-local coordinates
  final double radius; // logical pixels

  const _RevealedArea({required this.center, required this.radius});
}

class _FogOfWarPainter extends CustomPainter {
  final List<_RevealedArea> revealed;
  final Color fogColor;

  const _FogOfWarPainter({required this.revealed, required this.fogColor});

  @override
  void paint(Canvas canvas, Size size) {
    final fogPaint = Paint()..color = fogColor;

    if (revealed.isEmpty) {
      canvas.drawRect(Offset.zero & size, fogPaint);
      return;
    }

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, fogPaint);
    final holePaint = Paint()
      ..blendMode = BlendMode.clear
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    for (final area in revealed) {
      canvas.drawCircle(area.center, area.radius, holePaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FogOfWarPainter old) =>
      old.revealed != revealed || old.fogColor != fogColor;
}
