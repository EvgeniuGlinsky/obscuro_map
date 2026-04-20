import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../bloc/location_bloc.dart';
import '../bloc/location_state.dart';

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
  bool _myLocationEnabled = false;

  List<LatLng> _latLngPoints = const [];

  // Updated on every onCameraMove so the painter always has the live position.
  CameraPosition _camera = _initialCamera;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _goToMyLocation() async {
    LatLng? target;

    // Prefer the last point already tracked by the BLoC — instant, no I/O.
    final state = context.read<LocationBloc>().state;
    if (state is LocationTracking && state.points.isNotEmpty) {
      target = state.points.last;
    } else {
      // Fallback: cached OS position (fast, no fresh GPS fix required).
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) target = LatLng(pos.latitude, pos.longitude);
    }

    if (target != null) {
      await _controller?.animateCamera(CameraUpdate.newLatLng(target));
    }
  }

  Future<void> _changeZoom(double delta) =>
      _controller?.animateCamera(CameraUpdate.zoomBy(delta)) ?? Future.value();

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationBloc, LocationState>(
      listener: (context, state) {
        if (state is LocationTracking) {
          setState(() {
            _latLngPoints = state.points;
            if (!_myLocationEnabled) _myLocationEnabled = true;
          });
        } else if (state is LocationPermissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required to track your progress.',
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      },
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: (controller) => _controller = controller,
            // Update _camera on every frame of a pan/zoom gesture so the
            // painter recomputes screen positions without any async calls.
            onCameraMove: (pos) => setState(() => _camera = pos),
            myLocationEnabled: _myLocationEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _FogOfWarPainter(
                points: _latLngPoints,
                camera: _camera,
                fogColor: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                _MapButton(
                  icon: Icons.my_location,
                  onTap: _goToMyLocation,
                ),
                _MapButton(
                  icon: Icons.add,
                  onTap: () => _changeZoom(1),
                ),
                _MapButton(
                  icon: Icons.remove,
                  onTap: () {
                    () async {
                      throw Exception();
                    }();
                    _changeZoom(-1);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 22, color: Colors.black87),
        ),
      ),
    );
  }
}

class _FogOfWarPainter extends CustomPainter {
  const _FogOfWarPainter({
    required this.points,
    required this.camera,
    required this.fogColor,
  });

  final List<LatLng> points;
  final CameraPosition camera;
  final Color fogColor;

  static const _revealRadiusMeters = 15.0;

  @override
  void paint(Canvas canvas, Size size) {
    final fogPaint = Paint()..color = fogColor;

    if (points.isEmpty) {
      canvas.drawRect(Offset.zero & size, fogPaint);
      return;
    }

    // Scale factor: total map width/height in pixels at this zoom level.
    final scale = 256.0 * pow(2.0, camera.zoom);

    // Camera centre in Mercator pixel space.
    final cx = _mercatorX(camera.target.longitude) * scale;
    final cy = _mercatorY(camera.target.latitude) * scale;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, fogPaint);

    final holePaint = Paint()..blendMode = BlendMode.clear;

    for (final point in points) {
      // Point in Mercator pixel space → offset from camera centre → screen.
      final px = _mercatorX(point.longitude) * scale;
      final py = _mercatorY(point.latitude) * scale;
      final center = Offset(
        size.width / 2.0 + (px - cx),
        size.height / 2.0 + (py - cy),
      );

      // Radius in logical pixels for the current zoom and latitude.
      final metersPerPixel =
          156543.03392 *
          cos(point.latitude * pi / 180.0) /
          pow(2.0, camera.zoom);
      final radius = _revealRadiusMeters / metersPerPixel;

      // Blur is capped at 10% of the reveal radius so it stays subtle at
      // any zoom level and never dominates the visible cleared area.
      holePaint.maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.1);
      canvas.drawCircle(center, radius, holePaint);
    }

    canvas.restore();
  }

  // Normalised Web Mercator X in [0, 1].
  static double _mercatorX(double lng) => (lng + 180.0) / 360.0;

  // Normalised Web Mercator Y in [0, 1].
  static double _mercatorY(double lat) {
    final latRad = lat * pi / 180.0;
    return (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0;
  }

  @override
  bool shouldRepaint(_FogOfWarPainter old) =>
      old.points != points || old.camera != camera || old.fogColor != fogColor;
}
