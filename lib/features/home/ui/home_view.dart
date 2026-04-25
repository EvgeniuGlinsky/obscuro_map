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
  bool _hasCenteredOnUser = false;
  // Notifier owned by this state; the painter subscribes to it directly so
  // camera moves never trigger a full widget-tree rebuild.
  final _cameraNotifier = ValueNotifier<CameraPosition>(_initialCamera);

  // Pre-computed per-point constants (Mercator X/Y + base radius).
  // Rebuilt only when the GPS points list changes — not on every camera frame.
  List<_PointCache> _pointCache = const [];

  @override
  void dispose() {
    _cameraNotifier.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _goToMyLocation({bool animate = true}) async {
    LatLng? target;

    final state = context.read<LocationBloc>().state;
    if (state is LocationTracking && state.points.isNotEmpty) {
      target = state.points.last;
    } else {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) target = LatLng(pos.latitude, pos.longitude);
    }

    if (target != null) {
      final update = CameraUpdate.newLatLng(target);
      if (animate) {
        await _controller?.animateCamera(update);
      } else {
        await _controller?.moveCamera(update);
      }
    }
  }

  void _autoCenterOnce() {
    if (_hasCenteredOnUser) return;
    final state = context.read<LocationBloc>().state;
    if (state is LocationTracking && _controller != null) {
      _hasCenteredOnUser = true;
      _goToMyLocation(animate: false);
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
            // Pre-compute Mercator coords and per-point base radius once here,
            // not on every paint frame.
            _pointCache = state.points
                .map(_PointCache.fromLatLng)
                .toList(growable: false);
            if (!_myLocationEnabled) _myLocationEnabled = true;
          });
          _autoCenterOnce();
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
            onMapCreated: (controller) {
              _controller = controller;
              _autoCenterOnce();
            },
            // Write directly into the ValueNotifier — no setState, no rebuild.
            onCameraMove: (pos) => _cameraNotifier.value = pos,
            myLocationEnabled: _myLocationEnabled,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            rotateGesturesEnabled: false,
          ),
          // RepaintBoundary promotes the fog overlay to its own compositing
          // layer so its repaints never dirty sibling widgets.
          RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _FogOfWarPainter(
                  pointCache: _pointCache,
                  cameraNotifier: _cameraNotifier,
                  fogColor: Colors.black.withValues(alpha: 0.72),
                ),
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
                  onTap: () => _changeZoom(-1),
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

// ---------------------------------------------------------------------------
// Per-point pre-computed constants.
// Built once when the points list changes; reused on every paint frame.
// ---------------------------------------------------------------------------

final class _PointCache {
  const _PointCache(this.mx, this.my, this.baseRadius);

  // Normalised Web Mercator X/Y in [0, 1] — latitude/longitude never change.
  final double mx;
  final double my;

  // baseRadius = _revealRadiusMeters / (156543.03392 * cos(lat)).
  // Multiply by pow(2, zoom) at paint time to get the pixel radius.
  // Hoisting cos(lat) here saves one trig call per point per frame.
  final double baseRadius;

  static const _revealRadiusMeters = 15.0;

  factory _PointCache.fromLatLng(LatLng p) {
    final latRad = p.latitude * pi / 180.0;
    final cosLat = cos(latRad);
    return _PointCache(
      (p.longitude + 180.0) / 360.0,
      (1.0 - log(tan(latRad) + 1.0 / cosLat) / pi) / 2.0,
      _revealRadiusMeters / (156543.03392 * cosLat),
    );
  }
}

// ---------------------------------------------------------------------------
// Fog-of-war painter.
// ---------------------------------------------------------------------------

class _FogOfWarPainter extends CustomPainter {
  _FogOfWarPainter({
    required this.pointCache,
    required this.cameraNotifier,
    required this.fogColor,
  }) : super(repaint: cameraNotifier);
  // super(repaint:) subscribes the painter to the notifier, so it repaints
  // automatically on every camera move without setState touching the tree.

  final List<_PointCache> pointCache;
  final ValueNotifier<CameraPosition> cameraNotifier;
  final Color fogColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fogPaint = Paint()..color = fogColor;

    if (pointCache.isEmpty) {
      canvas.drawRect(Offset.zero & size, fogPaint);
      return;
    }

    final camera = cameraNotifier.value;
    final zoomScale = pow(2.0, camera.zoom) as double;
    final scale = 256.0 * zoomScale;

    // Approximate reveal radius at camera latitude; bail out if sub-pixel.
    final camLatRad = camera.target.latitude * pi / 180.0;
    final approxRadius =
        pointCache.first.baseRadius * zoomScale * cos(camLatRad);
    if (approxRadius < 0.5) {
      canvas.drawRect(Offset.zero & size, fogPaint);
      return;
    }

    // Camera centre in Mercator pixel space.
    final cx = (camera.target.longitude + 180.0) / 360.0 * scale;
    final cy =
        (1.0 - log(tan(camLatRad) + 1.0 / cos(camLatRad)) / pi) / 2.0 * scale;

    final hw = size.width / 2.0;
    final hh = size.height / 2.0;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, fogPaint);

    // Crisp circle fills via BlendMode.clear — no MaskFilter.blur.
    // Removing blur eliminates N full-screen GPU blur passes per frame,
    // which was the primary cause of the freeze on large open areas.
    final holePaint = Paint()..blendMode = BlendMode.clear;

    for (final p in pointCache) {
      final radius = p.baseRadius * zoomScale;
      final dx = hw + p.mx * scale - cx;
      final dy = hh + p.my * scale - cy;

      if (dx + radius < 0 ||
          dx - radius > size.width ||
          dy + radius < 0 ||
          dy - radius > size.height) {
        continue;
      }

      canvas.drawCircle(Offset(dx, dy), radius, holePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FogOfWarPainter old) =>
      old.pointCache != pointCache ||
      old.cameraNotifier != cameraNotifier ||
      old.fogColor != fogColor;
}
