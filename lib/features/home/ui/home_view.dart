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

  // Fog-of-war: set of revealed circle centres + radius (metres).
  // Populate this from your BLoC/provider as the user explores.
  final List<_RevealedArea> _revealed = [];

  // Latest set of geo-coordinates from the BLoC, kept so we can
  // reconvert them to screen offsets whenever the camera moves.
  List<LatLng> _latLngPoints = const [];

  // Incremented on every reconversion kick-off; stale async operations
  // compare against this value before committing results.
  int _rebuildGeneration = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Converts every stored [LatLng] to a widget-local [Offset] and
  /// derives the fog-hole radius in logical pixels for the current zoom.
  ///
  /// Uses a generation counter so that only the latest in-flight call
  /// can commit results; earlier calls are silently discarded.
  Future<void> _goToMyLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      return;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    await _controller?.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(position.latitude, position.longitude),
      ),
    );
  }

  Future<void> _changeZoom(double delta) =>
      _controller?.animateCamera(CameraUpdate.zoomBy(delta)) ?? Future.value();

  Future<void> _rebuildRevealed() async {
    final controller = _controller;
    if (controller == null) return;

    final generation = ++_rebuildGeneration;
    final snapshot = List<LatLng>.from(_latLngPoints);

    if (snapshot.isEmpty) {
      if (mounted) setState(() => _revealed.clear());
      return;
    }

    final zoom = await controller.getZoomLevel();
    if (!mounted || generation != _rebuildGeneration) return;

    // getScreenCoordinate returns physical pixels on Android, logical on iOS.
    // Dividing by devicePixelRatio normalises to logical pixels on all platforms.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final areas = <_RevealedArea>[];

    for (final point in snapshot) {
      final coord = await controller.getScreenCoordinate(point);
      if (!mounted || generation != _rebuildGeneration) return;

      // Metres per logical pixel at this zoom level and latitude.
      final mpp =
          156543.03392 * cos(point.latitude * pi / 180) / pow(2, zoom) * dpr;
      areas.add(
        _RevealedArea(
          center: Offset(coord.x / dpr, coord.y / dpr),
          radius: 5.0 / mpp,
        ),
      );
    }

    if (mounted && generation == _rebuildGeneration) {
      setState(() {
        _revealed
          ..clear()
          ..addAll(areas);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationBloc, LocationState>(
      listener: (context, state) {
        if (state is LocationTracking) {
          _latLngPoints = state.points;
          _rebuildRevealed();
        }
      },
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: (controller) {
              _controller = controller;
              _rebuildRevealed();
            },
            // Reconvert all points once the camera settles so the fog
            // overlay stays aligned with the map after pan / zoom.
            onCameraIdle: _rebuildRevealed,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _FogOfWarPainter(
                revealed: List.unmodifiable(_revealed),
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
