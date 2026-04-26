import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/map_constants.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/di/get_it.dart';
import '../../../core/hex/h3_service.dart';
import '../../../core/hex/hex_index.dart';
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

  final _h3 = getIt<H3Service>();

  // Painter inputs — written as ValueNotifiers so painter repaints don't
  // dirty the widget tree.
  final _cameraNotifier = ValueNotifier<CameraPosition>(_initialCamera);
  final _renderCellsNotifier = ValueNotifier<List<_RenderCell>>(const []);
  final _eraserPositionNotifier = ValueNotifier<Offset?>(null);

  // Identity-cache of the last cell-set the painter was built from. Lets
  // us skip the polygon rebuild on bloc emissions that didn't actually
  // change membership.
  Set<HexIndex>? _lastCells;

  late final _FogOfWarPainter _fogPainter;
  late final _EraserCirclePainter _eraserPainter;

  @override
  void initState() {
    super.initState();
    _fogPainter = _FogOfWarPainter(
      cellsNotifier: _renderCellsNotifier,
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
    _renderCellsNotifier.dispose();
    _eraserPositionNotifier.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _rebuildRenderCells(Set<HexIndex> stored) {
    if (stored.isEmpty) {
      _renderCellsNotifier.value = const [];
      return;
    }
    // Render at storage resolution unconditionally — never aggregate to a
    // coarser parent for display, or the apparent footprint of an
    // explored region would change with zoom.
    final out = <_RenderCell>[];
    for (final cell in stored) {
      final boundary = _h3.cellBoundary(cell);
      final mercators = boundary.map(_MercatorPoint.fromLatLng).toList(
            growable: false,
          );
      out.add(_RenderCell(cell, mercators));
    }
    _renderCellsNotifier.value = out;
  }

  Future<void> _goToMyLocation({bool animate = true}) async {
    LatLng? target;

    final state = context.read<LocationBloc>().state;
    if (state is LocationTracking && state.lastCell != null) {
      target = _h3.cellToLatLng(state.lastCell!);
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
      LocationCellsErased(
        center: _screenToLatLng(pos),
        radiusMeters: kEraserRadiusMeters,
      ),
    );
    _eraserPositionNotifier.value = pos;
  }

  void _onFillTap(Offset pos) {
    final bloc = context.read<LocationBloc>();
    final state = bloc.state;
    final walls = state is LocationTracking ? state.cells : const <HexIndex>{};
    final result = getIt<ComputeFillAreaUseCase>()(_screenToLatLng(pos), walls);
    switch (result) {
      case FillSuccess(:final cells):
        bloc.add(LocationCellsAdded(cells));
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
        state.lastCell != null &&
        _controller != null) {
      _hasCenteredOnUser = true;
      _controller!.moveCamera(
        CameraUpdate.newLatLngZoom(
          _h3.cellToLatLng(state.lastCell!),
          kInitialUserZoom,
        ),
      );
    }
  }

  Future<void> _changeZoom(double delta) =>
      _controller?.animateCamera(CameraUpdate.zoomBy(delta)) ?? Future.value();

  void _onLocationState(LocationState state) {
    if (state is LocationTracking) {
      // Identity-skip: only rebuild when membership actually changed.
      if (!identical(state.cells, _lastCells)) {
        _lastCells = state.cells;
        _rebuildRenderCells(state.cells);
      }
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
              onTapCancel: _onEraserGestureEnd,
              onPanUpdate: (d) => _onEraserGesture(d.localPosition),
              onPanEnd: (_) => _onEraserGestureEnd(),
              onPanCancel: _onEraserGestureEnd,
              child: const SizedBox.expand(),
            ),
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
  bool shouldRepaint(_EraserCirclePainter old) => false;
}

// ---------------------------------------------------------------------------
// Per-vertex pre-computed normalised Web Mercator coordinates.
// Built once per cell-resolution rebuild; reused on every frame.
// ---------------------------------------------------------------------------

final class _MercatorPoint {
  const _MercatorPoint(this.mx, this.my);
  final double mx;
  final double my;

  factory _MercatorPoint.fromLatLng(LatLng p) {
    final latRad = p.latitude * pi / 180.0;
    return _MercatorPoint(
      (p.longitude + 180.0) / 360.0,
      (1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0,
    );
  }
}

final class _RenderCell {
  const _RenderCell(this.index, this.boundary);
  final HexIndex index;
  final List<_MercatorPoint> boundary;
}

// ---------------------------------------------------------------------------
// Fog-of-war painter.
//
// One filled polygon per render-resolution cell, drawn with BlendMode.clear
// against an opaque fog rect. A subtle stroke is drawn on top of each cell
// to give the explored area a Civ-VI-style hex-mosaic texture.
// ---------------------------------------------------------------------------

class _FogOfWarPainter extends CustomPainter {
  _FogOfWarPainter({
    required this.cellsNotifier,
    required this.cameraNotifier,
    required this.fogColor,
  })  : _fogPaint = Paint()..color = fogColor,
        super(
          repaint: Listenable.merge([cellsNotifier, cameraNotifier]),
        );

  final ValueNotifier<List<_RenderCell>> cellsNotifier;
  final ValueNotifier<CameraPosition> cameraNotifier;
  final Color fogColor;

  final Paint _fogPaint;
  final Paint _layerPaint = Paint();
  final Paint _clearPaint = Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.fill;
  final Paint _outlinePaint = Paint()
    ..color = Colors.black.withValues(alpha: kHexOutlineOpacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = kHexOutlineWidth
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final cells = cellsNotifier.value;
    if (cells.isEmpty) {
      canvas.drawRect(Offset.zero & size, _fogPaint);
      return;
    }

    final camera = cameraNotifier.value;
    final zoomScale = pow(2.0, camera.zoom) as double;
    final scale = 256.0 * zoomScale;
    final camLatRad = camera.target.latitude * pi / 180.0;
    final cosLat = cos(camLatRad);
    final cx = (camera.target.longitude + 180.0) / 360.0 * scale;
    final cy = (1.0 - log(tan(camLatRad) + 1.0 / cosLat) / pi) / 2.0 * scale;
    final hw = size.width / 2.0;
    final hh = size.height / 2.0;

    canvas.saveLayer(Offset.zero & size, _layerPaint);
    canvas.drawRect(Offset.zero & size, _fogPaint);

    // Cull cells whose bounding box is fully off-screen. Cheap pre-projection
    // bounds check using the first vertex's projected position is "good
    // enough" — false positives just incur a polygon construction.
    final clipPad = 64.0; // px slack so cells straddling the edge still draw
    final left = -clipPad;
    final right = size.width + clipPad;
    final top = -clipPad;
    final bottom = size.height + clipPad;

    final clearPath = Path()..fillType = PathFillType.nonZero;
    final outlinePath = Path();

    for (final cell in cells) {
      final pts = cell.boundary;
      if (pts.isEmpty) continue;

      // Project + accumulate bounds in one pass.
      final firstDx = hw + pts[0].mx * scale - cx;
      final firstDy = hh + pts[0].my * scale - cy;
      var minX = firstDx, maxX = firstDx;
      var minY = firstDy, maxY = firstDy;
      final projected = List<Offset>.filled(pts.length, Offset.zero);
      projected[0] = Offset(firstDx, firstDy);
      for (var i = 1; i < pts.length; i++) {
        final dx = hw + pts[i].mx * scale - cx;
        final dy = hh + pts[i].my * scale - cy;
        projected[i] = Offset(dx, dy);
        if (dx < minX) minX = dx;
        if (dx > maxX) maxX = dx;
        if (dy < minY) minY = dy;
        if (dy > maxY) maxY = dy;
      }
      if (maxX < left || minX > right || maxY < top || minY > bottom) continue;

      clearPath.moveTo(projected[0].dx, projected[0].dy);
      outlinePath.moveTo(projected[0].dx, projected[0].dy);
      for (var i = 1; i < projected.length; i++) {
        clearPath.lineTo(projected[i].dx, projected[i].dy);
        outlinePath.lineTo(projected[i].dx, projected[i].dy);
      }
      clearPath.close();
      outlinePath.close();
    }

    canvas.drawPath(clearPath, _clearPaint);
    canvas.restore();

    // Outlines drawn after restore() so they sit on top of the cleared
    // region rather than being erased by the clear blend.
    canvas.drawPath(outlinePath, _outlinePaint);
  }

  @override
  bool shouldRepaint(_FogOfWarPainter old) => false;
}
