import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/map_constants.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/di/get_it.dart';
import '../../auth/ui/sign_in_button.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import '../bloc/location_state.dart';
import '../domain/usecases/compute_fill_area_usecase.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  static const _initialCamera = CameraPosition(
    target: kInitialCameraTarget,
    zoom: kInitialCameraZoom,
  );

  GoogleMapController? _controller;
  bool _myLocationEnabled = false;
  bool _hasCenteredOnUser = false;
  bool _eraserActive = false;
  bool _fillActive = false;

  // All four notifiers below drive painter repaints WITHOUT widget rebuilds.
  // The painter subscribes via Listenable.merge, so updates skip the build
  // pipeline entirely and incur only a single canvas repaint.
  final _cameraNotifier = ValueNotifier<CameraPosition>(_initialCamera);
  final _trackNotifier = ValueNotifier<List<_PointCache>>(const []);
  final _fillNotifier = ValueNotifier<List<_PointCache>>(const []);
  final _eraserPositionNotifier = ValueNotifier<Offset?>(null);

  // Identity-cache the latest source lists so we skip rebuilding _PointCache
  // for whichever list didn't actually change between bloc emissions.
  List<LatLng>? _lastTrackSource;
  List<LatLng>? _lastFillSource;

  // Painter instances are constructed once in initState so their cached Paint
  // objects survive across rebuilds and GPS updates.
  late final _FogOfWarPainter _fogPainter;
  late final _EraserCirclePainter _eraserPainter;

  @override
  void initState() {
    super.initState();
    _fogPainter = _FogOfWarPainter(
      trackNotifier: _trackNotifier,
      fillNotifier: _fillNotifier,
      cameraNotifier: _cameraNotifier,
      fogColor: kFogColor,
    );
    _eraserPainter = _EraserCirclePainter(
      positionNotifier: _eraserPositionNotifier,
      cameraNotifier: _cameraNotifier,
    );
  }

  @override
  void dispose() {
    _cameraNotifier.dispose();
    _trackNotifier.dispose();
    _fillNotifier.dispose();
    _eraserPositionNotifier.dispose();
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

  // Converts a screen position to a geographic coordinate using the same
  // Mercator projection used by the fog painter — no async map SDK call needed.
  LatLng _screenToLatLng(Offset pos) {
    final camera = _cameraNotifier.value;
    final zoomScale = pow(2.0, camera.zoom) as double;
    final scale = 256.0 * zoomScale;
    final camLatRad = camera.target.latitude * pi / 180.0;
    final cosLat = cos(camLatRad);
    final cx = (camera.target.longitude + 180.0) / 360.0 * scale;
    final cy = (1.0 - log(tan(camLatRad) + 1.0 / cosLat) / pi) / 2.0 * scale;
    final size = MediaQuery.sizeOf(context);
    final mx = (pos.dx - size.width / 2.0 + cx) / scale;
    final my = (pos.dy - size.height / 2.0 + cy) / scale;
    final lng = mx * 360.0 - 180.0;
    final lat = (2.0 * atan(exp(pi * (1.0 - 2.0 * my))) - pi / 2.0) * 180.0 / pi;
    return LatLng(lat, lng);
  }

  void _onEraserGesture(Offset pos) {
    context.read<LocationBloc>().add(
      LocationPointsErased(
        center: _screenToLatLng(pos),
        radiusMeters: kEraserRadiusMeters,
      ),
    );
    _eraserPositionNotifier.value = pos; // notifier-only; no setState
  }

  void _onFillTap(Offset pos) {
    final bloc = context.read<LocationBloc>();
    final state = bloc.state;
    final trackPoints =
        state is LocationTracking ? state.points : const <LatLng>[];
    final result = getIt<ComputeFillAreaUseCase>()(
      _screenToLatLng(pos),
      trackPoints,
    );
    switch (result) {
      case FillSuccess(:final points):
        bloc.add(LocationAreaFilled(fillPoints: points));
      case FillNotEnclosed():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kFillNotEnclosedMessage)),
        );
      case FillTooLarge():
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(kFillTooLargeMessage)),
        );
    }
  }

  void _onEraserGestureEnd() {
    context.read<LocationBloc>().add(const LocationProgressSaved());
    _eraserPositionNotifier.value = null;
  }

  void _autoCenterOnce() {
    if (_hasCenteredOnUser) return;
    final state = context.read<LocationBloc>().state;
    if (state is LocationTracking &&
        state.points.isNotEmpty &&
        _controller != null) {
      _hasCenteredOnUser = true;
      _controller!.moveCamera(
        CameraUpdate.newLatLngZoom(state.points.last, kInitialUserZoom),
      );
    }
  }

  Future<void> _changeZoom(double delta) =>
      _controller?.animateCamera(CameraUpdate.zoomBy(delta)) ?? Future.value();

  void _onLocationState(LocationState state) {
    if (state is LocationTracking) {
      // Identity-skip: only rebuild the cache whose source actually changed.
      if (!identical(state.points, _lastTrackSource)) {
        _lastTrackSource = state.points;
        _trackNotifier.value =
            state.points.map(_PointCache.fromLatLng).toList(growable: false);
      }
      if (!identical(state.fillPoints, _lastFillSource)) {
        _lastFillSource = state.fillPoints;
        _fillNotifier.value = state.fillPoints
            .map(_PointCache.fromLatLng)
            .toList(growable: false);
      }
      // One-time setState — flips on the first fix and never again.
      if (!_myLocationEnabled) {
        setState(() => _myLocationEnabled = true);
      }
      _autoCenterOnce();
    } else if (state is LocationPermissionDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(kLocationPermissionDeniedMessage),
          duration: kSnackBarDuration,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapInteractive = !_eraserActive && !_fillActive;
    return BlocListener<LocationBloc, LocationState>(
      listener: (_, state) => _onLocationState(state),
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
            scrollGesturesEnabled: mapInteractive,
            zoomGesturesEnabled: mapInteractive,
            tiltGesturesEnabled: mapInteractive,
          ),
          // RepaintBoundary promotes the fog overlay to its own compositing
          // layer so its repaints never dirty sibling widgets.
          RepaintBoundary(
            child: IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _fogPainter,
              ),
            ),
          ),
          if (_fillActive)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _onFillTap(d.localPosition),
              child: const SizedBox.expand(),
            ),
          if (_eraserActive) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _onEraserGesture(d.localPosition),
              onTapUp: (_) => _onEraserGestureEnd(),
              // onTapCancel covers the case where the tap is upgraded to a
              // pan or the gesture loses arena — without it, neither tapUp
              // nor panEnd would fire and the cloud mirror would be skipped.
              onTapCancel: _onEraserGestureEnd,
              onPanUpdate: (d) => _onEraserGesture(d.localPosition),
              onPanEnd: (_) => _onEraserGestureEnd(),
              onPanCancel: _onEraserGestureEnd,
              child: const SizedBox.expand(),
            ),
            // The painter no-ops when position is null, so we keep it
            // mounted while the eraser tool is active and let pan events
            // drive repaints via the position notifier alone.
            RepaintBoundary(
              child: IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _eraserPainter,
                ),
              ),
            ),
          ],
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SignInButton(),
                ),
              ),
            ),
          ),
          Positioned(
            right: kMapButtonsRightInset,
            bottom: kMapButtonsBottomInset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: kMapButtonsSpacing,
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
                _MapButton(
                  icon: Icons.auto_fix_normal,
                  onTap: () => setState(() {
                    _eraserActive = !_eraserActive;
                    if (_eraserActive) _fillActive = false;
                  }),
                  isActive: _eraserActive,
                ),
                _MapButton(
                  icon: Icons.water_drop_outlined,
                  onTap: () => setState(() {
                    _fillActive = !_fillActive;
                    if (_fillActive) _eraserActive = false;
                  }),
                  isActive: _fillActive,
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
  const _MapButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? Colors.red.shade700 : Colors.white,
      shape: const CircleBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: kMapButtonPadding,
          child: Icon(
            icon,
            size: kMapButtonIconSize,
            color: isActive ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Eraser circle overlay — shows the erase radius while the finger is down.
// ---------------------------------------------------------------------------

class _EraserCirclePainter extends CustomPainter {
  _EraserCirclePainter({
    required this.positionNotifier,
    required this.cameraNotifier,
  }) : super(repaint: Listenable.merge([positionNotifier, cameraNotifier]));

  final ValueNotifier<Offset?> positionNotifier;
  final ValueNotifier<CameraPosition> cameraNotifier;

  // Paints are immutable for this overlay — instantiate once, reuse forever.
  static final Paint _fillPaint = Paint()
    ..color = kEraserOverlayColor
    ..style = PaintingStyle.fill;
  static final Paint _strokePaint = Paint()
    ..color = kEraserStrokeColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = kEraserStrokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final position = positionNotifier.value;
    if (position == null) return;
    final camera = cameraNotifier.value;
    final zoomScale = pow(2.0, camera.zoom) as double;
    final cosLat = cos(camera.target.latitude * pi / 180.0);
    final radiusPx = kEraserRadiusMeters / (156543.03392 * cosLat) * zoomScale;
    canvas.drawCircle(position, radiusPx, _fillPaint);
    canvas.drawCircle(position, radiusPx, _strokePaint);
  }

  @override
  bool shouldRepaint(_EraserCirclePainter old) => false; // driven by repaint listenable
}

// ---------------------------------------------------------------------------
// Per-point pre-computed Mercator coordinates.
// Built once when the points list changes; reused on every paint frame.
// ---------------------------------------------------------------------------

final class _PointCache {
  const _PointCache(this.mx, this.my);

  // Normalised Web Mercator X/Y in [0, 1] — constant for this GPS coordinate.
  final double mx;
  final double my;

  factory _PointCache.fromLatLng(LatLng p) {
    final latRad = p.latitude * pi / 180.0;
    return _PointCache(
      (p.longitude + 180.0) / 360.0,
      (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0,
    );
  }
}

// ---------------------------------------------------------------------------
// Fog-of-war painter.
// ---------------------------------------------------------------------------

class _FogOfWarPainter extends CustomPainter {
  _FogOfWarPainter({
    required this.trackNotifier,
    required this.fillNotifier,
    required this.cameraNotifier,
    required this.fogColor,
  })  : _fogPaint = Paint()..color = fogColor,
        super(
          repaint: Listenable.merge(
            [trackNotifier, fillNotifier, cameraNotifier],
          ),
        );

  final ValueNotifier<List<_PointCache>> trackNotifier;
  final ValueNotifier<List<_PointCache>> fillNotifier;
  final ValueNotifier<CameraPosition> cameraNotifier;
  final Color fogColor;

  // Cached, mutable paint objects. Mutating fields (e.g. strokeWidth) per
  // frame is fine — paint objects are designed for reuse — and avoids the
  // per-repaint allocation pressure of constructing fresh Paints.
  final Paint _fogPaint;
  final Paint _layerPaint = Paint();
  final Paint _strokePaint = Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _clearCirclePaint = Paint()..blendMode = BlendMode.clear;

  @override
  void paint(Canvas canvas, Size size) {
    final trackCache = trackNotifier.value;
    final fillCache = fillNotifier.value;

    if (trackCache.isEmpty && fillCache.isEmpty) {
      canvas.drawRect(Offset.zero & size, _fogPaint);
      return;
    }

    final camera = cameraNotifier.value;
    final zoomScale = pow(2.0, camera.zoom) as double;
    final scale = 256.0 * zoomScale;

    final camLatRad = camera.target.latitude * pi / 180.0;
    final cosLat = cos(camLatRad);
    // Uniform stroke radius derived from camera latitude. Points within the
    // visible area share nearly the same latitude, so this approximation is
    // valid and avoids per-point trig entirely.
    final strokeRadius =
        kRevealRadiusMeters / (156543.03392 * cosLat) * zoomScale;
    if (strokeRadius < 0.5) {
      canvas.drawRect(Offset.zero & size, _fogPaint);
      return;
    }

    final cx = (camera.target.longitude + 180.0) / 360.0 * scale;
    final cy = (1.0 - log(tan(camLatRad) + 1.0 / cosLat) / pi) / 2.0 * scale;
    final hw = size.width / 2.0;
    final hh = size.height / 2.0;

    final gapThresholdPx =
        kSegmentGapMeters / (156543.03392 * cosLat) * zoomScale;
    final gapSq = gapThresholdPx * gapThresholdPx;

    // One drawPath replaces N drawCircle calls; the GPU renders the capsule
    // shapes (rounded line segments) in a single pass.
    final path = Path();
    var prevDx = 0.0;
    var prevDy = 0.0;
    var started = false;

    for (final p in trackCache) {
      final dx = hw + p.mx * scale - cx;
      final dy = hh + p.my * scale - cy;
      if (!started) {
        path.moveTo(dx, dy);
        started = true;
      } else {
        final ddx = dx - prevDx;
        final ddy = dy - prevDy;
        if (ddx * ddx + ddy * ddy > gapSq) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }
      prevDx = dx;
      prevDy = dy;
    }

    canvas.saveLayer(Offset.zero & size, _layerPaint);
    canvas.drawRect(Offset.zero & size, _fogPaint);

    _strokePaint.strokeWidth = strokeRadius * 2.0;
    canvas.drawPath(path, _strokePaint);

    if (fillCache.isNotEmpty) {
      for (final p in fillCache) {
        canvas.drawCircle(
          Offset(hw + p.mx * scale - cx, hh + p.my * scale - cy),
          strokeRadius,
          _clearCirclePaint,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_FogOfWarPainter old) => false; // driven by repaint listenable
}
