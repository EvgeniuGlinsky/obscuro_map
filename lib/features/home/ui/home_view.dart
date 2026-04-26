import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/constants/map_constants.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/di/get_it.dart';
import '../../../core/hex/grid_lod.dart';
import '../../../core/hex/h3_service.dart';
import '../../../core/hex/hex_index.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/map_style.dart';
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
  bool _hasCenteredOnUser = false;
  bool _eraserActive = false;
  bool _fillActive = false;
  bool _gridOverlayEnabled = false;

  final _h3 = getIt<H3Service>();

  // Painter inputs — written as ValueNotifiers so painter repaints don't
  // dirty the widget tree.
  final _cameraNotifier = ValueNotifier<CameraPosition>(_initialCamera);
  final _renderCellsNotifier = ValueNotifier<List<_RenderCell>>(const []);
  final _gridCellsNotifier = ValueNotifier<List<_RenderCell>>(const []);
  final _eraserPositionNotifier = ValueNotifier<Offset?>(null);

  // User-location marker — bitmap is rendered once after the first frame
  // (we need devicePixelRatio from MediaQuery), then the position is
  // pushed into [_userMarkerNotifier] on every bloc emission so the
  // GoogleMap rebuilds via ValueListenableBuilder rather than via setState
  // on this widget.
  final _userMarkerNotifier = ValueNotifier<Set<Marker>>(const {});
  BitmapDescriptor? _userMarkerIcon;
  HexIndex? _pendingUserMarkerCell;

  // Identity-cache of the last cell-set the painter was built from. Lets
  // us skip the polygon rebuild on bloc emissions that didn't actually
  // change membership.
  Set<HexIndex>? _lastCells;

  // Per-cell boundary cache for the grid overlay. Cells re-entering the
  // viewport during pan reuse their projected vertices instead of crossing
  // the FFI boundary again. Cleared on every resolution change.
  final Map<HexIndex, List<_MercatorPoint>> _gridBoundaryCache = {};
  int _gridCachedResolution = -1;

  late final _FogOfWarPainter _fogPainter;
  late final _EraserCirclePainter _eraserPainter;

  @override
  void initState() {
    super.initState();
    _fogPainter = _FogOfWarPainter(
      cellsNotifier: _renderCellsNotifier,
      gridCellsNotifier: _gridCellsNotifier,
      cameraNotifier: _cameraNotifier,
      fogColor: kFogColor,
    );
    _eraserPainter = _EraserCirclePainter(
      positionNotifier: _eraserPositionNotifier,
      cameraNotifier: _cameraNotifier,
    );
    // The grid overlay polygon depends on viewport, so recompute on every
    // camera change. The boundary cache + cheap polygonToCells FFI keep
    // this well under one-frame budget; the listener no-ops when the
    // overlay is off.
    _cameraNotifier.addListener(_onCameraChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0;
      _userMarkerIcon = await _buildUserMarkerIcon(ratio);
      // If a position arrived while the bitmap was being built, mount it.
      if (_pendingUserMarkerCell != null) {
        _setUserMarkerCell(_pendingUserMarkerCell!);
      }
    });
  }

  @override
  void dispose() {
    _cameraNotifier.removeListener(_onCameraChanged);
    _cameraNotifier.dispose();
    _renderCellsNotifier.dispose();
    _gridCellsNotifier.dispose();
    _eraserPositionNotifier.dispose();
    _userMarkerNotifier.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _setUserMarkerCell(HexIndex cell) {
    if (_userMarkerIcon == null) {
      // Bitmap not ready yet — remember the latest cell, mount when it is.
      _pendingUserMarkerCell = cell;
      return;
    }
    final pos = _h3.cellToLatLng(cell);
    _userMarkerNotifier.value = {
      Marker(
        markerId: const MarkerId('user'),
        position: pos,
        icon: _userMarkerIcon!,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 999,
      ),
    };
  }

  /// Renders the user-location marker bitmap once on app start.
  /// Composition matches the design hand-off:
  ///   * outer glow — radius 34, radial gradient #9D8FCC 0.55 → 0
  ///   * ring — radius 13, fill rgba(107,90,155,0.22), stroke
  ///     rgba(193,189,210,0.35) at 1.5pt
  ///   * inner dot — radius 6, fill #9D8FCC
  ///   * white centre — radius 3
  /// Total icon area sized to fit the glow with comfortable padding.
  Future<BitmapDescriptor> _buildUserMarkerIcon(double pixelRatio) async {
    const double logical = 80; // logical pt edge of the bitmap
    final double pixels = logical * pixelRatio;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(pixelRatio);

    const centre = Offset(logical / 2, logical / 2);

    // Glow.
    final glowRect = Rect.fromCircle(center: centre, radius: 34);
    canvas.drawCircle(
      centre,
      34,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color.fromRGBO(157, 143, 204, 0.55),
            Color.fromRGBO(157, 143, 204, 0.0),
          ],
        ).createShader(glowRect),
    );
    // Ring fill.
    canvas.drawCircle(
      centre,
      13,
      Paint()..color = const Color.fromRGBO(107, 90, 155, 0.22),
    );
    // Ring stroke.
    canvas.drawCircle(
      centre,
      13,
      Paint()
        ..color = const Color.fromRGBO(193, 189, 210, 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Inner purple dot.
    canvas.drawCircle(
      centre,
      6,
      Paint()..color = kColorPurpleMid,
    );
    // White centre.
    canvas.drawCircle(
      centre,
      3,
      Paint()..color = Colors.white,
    );

    final image = await recorder
        .endRecording()
        .toImage(pixels.toInt(), pixels.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.bytes(
      bytes,
      imagePixelRatio: pixelRatio,
    );
  }

  void _onCameraChanged() {
    if (!_gridOverlayEnabled) return;
    _rebuildGridCells();
  }

  void _rebuildGridCells() {
    if (!_gridOverlayEnabled) {
      if (_gridCellsNotifier.value.isNotEmpty) {
        _gridCellsNotifier.value = const [];
      }
      return;
    }
    final cam = _cameraNotifier.value;
    final res = pickGridResolution(cam.zoom);
    if (res != _gridCachedResolution) {
      _gridBoundaryCache.clear();
      _gridCachedResolution = res;
    }

    // At coarse resolutions the viewport polygon wraps the world or runs
    // past ±85° latitude where Mercator is undefined — `polygonToCells`
    // returns nothing or partial results. Enumerate globally instead;
    // the painter then culls everything off-screen.
    final List<HexIndex> indices;
    if (res <= kGridGlobalEnumerationMaxResolution) {
      indices = _h3.allCellsAtResolution(res);
    } else {
      final perimeter = _viewportPolygon();
      if (perimeter == null) return;
      indices = _h3.cellsInPolygon(perimeter, res);
    }

    final out = List<_RenderCell>.generate(indices.length, (i) {
      final cell = indices[i];
      final cached = _gridBoundaryCache[cell];
      if (cached != null) return _RenderCell(cell, cached);
      final boundary = _h3
          .cellBoundary(cell)
          .map(_MercatorPoint.fromLatLng)
          .toList(growable: false);
      _gridBoundaryCache[cell] = boundary;
      return _RenderCell(cell, boundary);
    }, growable: false);
    _gridCellsNotifier.value = out;
  }

  /// Lat/lng polygon enclosing the visible viewport, with a small margin so
  /// cells just past the screen edge are also fetched (lets the user pan
  /// briefly without a stutter while waiting for the next rebuild).
  /// Returns `null` before the first frame, when MediaQuery has no size.
  List<LatLng>? _viewportPolygon() {
    final size = MediaQuery.maybeSizeOf(context);
    if (size == null || size.isEmpty) return null;
    const padFactor = 1.25;
    final padX = size.width * (padFactor - 1.0) / 2.0;
    final padY = size.height * (padFactor - 1.0) / 2.0;
    return [
      _screenToLatLng(Offset(-padX, -padY)),
      _screenToLatLng(Offset(-padX, size.height + padY)),
      _screenToLatLng(Offset(size.width + padX, size.height + padY)),
      _screenToLatLng(Offset(size.width + padX, -padY)),
    ];
  }

  void _toggleGridOverlay() {
    setState(() {
      _gridOverlayEnabled = !_gridOverlayEnabled;
    });
    if (_gridOverlayEnabled) {
      _rebuildGridCells();
    } else {
      _gridCellsNotifier.value = const [];
      _gridBoundaryCache.clear();
      _gridCachedResolution = -1;
    }
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
      if (state.lastCell != null) {
        _setUserMarkerCell(state.lastCell!);
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
          // Wrap GoogleMap so marker updates rebuild only this subtree
          // (not the whole HomeView, which would also dirty the painter
          // RepaintBoundaries).
          ValueListenableBuilder<Set<Marker>>(
            valueListenable: _userMarkerNotifier,
            builder: (_, markers, _) => GoogleMap(
              initialCameraPosition: _initialCamera,
              style: kMapStyleJson,
              onMapCreated: (controller) {
                _controller = controller;
                _autoCenterOnce();
              },
              onCameraMove: (pos) => _cameraNotifier.value = pos,
              // Custom purple marker replaces Google's blue dot so the
              // user-location indicator matches the design hand-off.
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: mapInteractive,
              zoomGesturesEnabled: mapInteractive,
              tiltGesturesEnabled: mapInteractive,
              markers: markers,
            ),
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
          // Sign-in pill: 66pt from the top of the screen, horizontally
          // centred, exactly per the design handoff.
          const Positioned(
            top: kSignInPillTopOffset,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: SignInButton(),
            ),
          ),
          // Map controls — right edge, vertically centred (per design).
          Positioned.fill(
            right: kMapButtonsRightInset,
            child: Align(
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: kMapButtonsSpacing,
              children: [
                _MapButton(
                  icon: _MapIcon.locate,
                  onTap: _goToMyLocation,
                ),
                _MapButton(
                  icon: _MapIcon.plus,
                  onTap: () => _changeZoom(1),
                ),
                _MapButton(
                  icon: _MapIcon.minus,
                  onTap: () => _changeZoom(-1),
                ),
                _MapButton(
                  icon: _MapIcon.erase,
                  onTap: () => setState(() {
                    _eraserActive = !_eraserActive;
                    if (_eraserActive) _fillActive = false;
                  }),
                  isActive: _eraserActive,
                ),
                _MapButton(
                  icon: _MapIcon.fill,
                  onTap: () => setState(() {
                    _fillActive = !_fillActive;
                    if (_fillActive) _eraserActive = false;
                  }),
                  isActive: _fillActive,
                ),
                _MapButton(
                  icon: _MapIcon.grid,
                  onTap: _toggleGridOverlay,
                  isActive: _gridOverlayEnabled,
                ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MapIcon { locate, plus, minus, erase, fill, grid }

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final _MapIcon icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isActive ? kMapButtonActiveIcon : kMapButtonInactiveIcon;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: kMapButtonSize,
        height: kMapButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? null : kMapButtonInactiveBg,
          gradient: isActive ? kMapButtonActiveGradient : null,
          border: Border.all(
            color: isActive
                ? kMapButtonActiveBorder
                : kMapButtonInactiveBorder,
            width: 1,
          ),
          boxShadow: isActive
              ? kMapButtonActiveShadow
              : kMapButtonInactiveShadow,
        ),
        child: CustomPaint(
          painter: _MapIconPainter(icon: icon, color: iconColor),
        ),
      ),
    );
  }
}

/// Renders the panel-button icons exactly as defined in the design's SVGs
/// (see `lib/new_design/Obscuro Map Design.html`, `ICONS` map). The native
/// Material icons aren't a close enough match for the hi-fi handoff —
/// stroke widths, end-caps and proportions all differ — so we paint the
/// paths directly.
class _MapIconPainter extends CustomPainter {
  _MapIconPainter({required this.icon, required this.color});

  final _MapIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // All source icons are designed in a 20–22 pt viewBox; centre on the
    // 48-pt button and scale uniformly.
    const double sourceSize = 22;
    final scale = (size.shortestSide * (sourceSize / 48.0)) / sourceSize;
    canvas.save();
    canvas.translate(
      (size.width - sourceSize * scale) / 2,
      (size.height - sourceSize * scale) / 2,
    );
    canvas.scale(scale);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icon) {
      case _MapIcon.locate:
        // Crosshair on a 22×22 viewBox.
        stroke.strokeWidth = 2.0;
        canvas.drawCircle(const Offset(11, 11), 4, stroke);
        canvas.drawLine(const Offset(11, 1.5), const Offset(11, 5.5), stroke);
        canvas.drawLine(const Offset(11, 16.5), const Offset(11, 20.5), stroke);
        canvas.drawLine(const Offset(1.5, 11), const Offset(5.5, 11), stroke);
        canvas.drawLine(const Offset(16.5, 11), const Offset(20.5, 11), stroke);
        break;
      case _MapIcon.plus:
        // Source viewBox is 20×20. Offset to centre inside the 22 frame.
        canvas.translate(1, 1);
        stroke.strokeWidth = 2.2;
        canvas.drawLine(const Offset(10, 3), const Offset(10, 17), stroke);
        canvas.drawLine(const Offset(3, 10), const Offset(17, 10), stroke);
        break;
      case _MapIcon.minus:
        canvas.translate(1, 1);
        stroke.strokeWidth = 2.2;
        canvas.drawLine(const Offset(4, 10), const Offset(16, 10), stroke);
        break;
      case _MapIcon.erase:
        // Trash can. Source viewBox 20×20.
        canvas.translate(1, 1);
        stroke.strokeWidth = 1.7;
        // Body:  M4 6.5h12l-1.1 10H5.1L4 6.5z
        final body = Path()
          ..moveTo(4, 6.5)
          ..relativeLineTo(12, 0)
          ..lineTo(14.9, 16.5)
          ..lineTo(5.1, 16.5)
          ..close();
        canvas.drawPath(body, stroke);
        // Lid line.
        canvas.drawLine(const Offset(2.5, 6.5), const Offset(17.5, 6.5), stroke);
        // Handle:  M7.5 6.5V4.5h5v2
        final handle = Path()
          ..moveTo(7.5, 6.5)
          ..lineTo(7.5, 4.5)
          ..lineTo(12.5, 4.5)
          ..lineTo(12.5, 6.5);
        canvas.drawPath(handle, stroke);
        break;
      case _MapIcon.fill:
        // Paint-drop + brush stem. Source viewBox 20×20.
        canvas.translate(1, 1);
        stroke.strokeWidth = 1.7;
        // Drop:
        // M13.5 14C13.5 15.8 12.4 17 11 17 C9.6 17 8.5 15.8 8.5 14
        // C8.5 11.8 11 8 11 8 C11 8 13.5 11.8 13.5 14Z
        final drop = Path()
          ..moveTo(13.5, 14)
          ..cubicTo(13.5, 15.8, 12.4, 17, 11, 17)
          ..cubicTo(9.6, 17, 8.5, 15.8, 8.5, 14)
          ..cubicTo(8.5, 11.8, 11, 8, 11, 8)
          ..cubicTo(11, 8, 13.5, 11.8, 13.5, 14)
          ..close();
        canvas.drawPath(drop, stroke);
        // Brush stem: M3.5 3 L 12 11.5
        canvas.drawLine(const Offset(3.5, 3), const Offset(12, 11.5), stroke);
        // Brush head.
        stroke.strokeWidth = 1.6;
        final head = Path()
          ..moveTo(3.5, 3)
          ..quadraticBezierTo(5.5, 1, 7.5, 3)
          ..quadraticBezierTo(9.5, 5, 7.5, 7)
          ..close();
        canvas.drawPath(head, stroke);
        break;
      case _MapIcon.grid:
        // Hexagon with 3 internal cross-lines. Source viewBox 21×21.
        canvas.translate(0.5, 0.5);
        stroke.strokeWidth = 1.7;
        final hex = Path()
          ..moveTo(10.5, 2)
          ..lineTo(17, 6)
          ..lineTo(17, 14)
          ..lineTo(10.5, 18)
          ..lineTo(4, 14)
          ..lineTo(4, 6)
          ..close();
        canvas.drawPath(hex, stroke);
        final inner = Paint()
          ..color = color.withValues(alpha: color.a * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(4, 6), const Offset(17, 6), inner);
        canvas.drawLine(const Offset(4, 14), const Offset(17, 14), inner);
        canvas.drawLine(const Offset(10.5, 2), const Offset(10.5, 18), inner);
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapIconPainter old) =>
      old.icon != icon || old.color != color;
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
// Compositing strategy (one saveLayer per frame):
//   1. Draw opaque fog over the whole canvas.
//   2. If the user has toggled the grid overlay on, stroke the reference
//      lattice for cells visible in the viewport. These strokes sit on top
//      of fog inside the layer.
//   3. Punch out explored cells with BlendMode.clear — this erases both fog
//      AND the grid lines wherever the user has explored, so the lattice
//      only ever shows on unexplored area.
//   4. Restore the layer (composites fog+grid+holes onto the canvas).
//   5. Stroke the explored-cell outlines on top — gives the cleared area a
//      hex-mosaic texture (Civ VI vibe).
// ---------------------------------------------------------------------------

class _FogOfWarPainter extends CustomPainter {
  _FogOfWarPainter({
    required this.cellsNotifier,
    required this.gridCellsNotifier,
    required this.cameraNotifier,
    required this.fogColor,
  })  : _fogPaint = Paint()..color = fogColor,
        super(
          repaint: Listenable.merge(
            [cellsNotifier, gridCellsNotifier, cameraNotifier],
          ),
        );

  final ValueNotifier<List<_RenderCell>> cellsNotifier;
  final ValueNotifier<List<_RenderCell>> gridCellsNotifier;
  final ValueNotifier<CameraPosition> cameraNotifier;
  final Color fogColor;

  final Paint _fogPaint;
  final Paint _layerPaint = Paint();
  final Paint _clearPaint = Paint()
    ..blendMode = BlendMode.clear
    ..style = PaintingStyle.fill;
  final Paint _outlinePaint = Paint()
    ..color = kColorExploredHexOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = kHexOutlineWidth
    ..strokeJoin = StrokeJoin.round;
  final Paint _gridPaint = Paint()
    ..color = kColorUnexploredHexOutline
    ..style = PaintingStyle.stroke
    ..strokeWidth = kHexGridOverlayWidth
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final cells = cellsNotifier.value;
    final gridCells = gridCellsNotifier.value;

    if (cells.isEmpty && gridCells.isEmpty) {
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

    final clipPad = 64.0; // px slack so cells straddling the edge still draw
    final left = -clipPad;
    final right = size.width + clipPad;
    final top = -clipPad;
    final bottom = size.height + clipPad;

    // Build the explored cells' clear-fill path and a matching outline path.
    final clearPath = Path()..fillType = PathFillType.nonZero;
    final outlinePath = Path();
    _appendCellsToPath(
      cells: cells,
      hw: hw,
      hh: hh,
      scale: scale,
      cx: cx,
      cy: cy,
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      paths: [clearPath, outlinePath],
    );

    // Build the grid overlay path (only when the toggle is on — otherwise
    // gridCells is empty and this is a no-op).
    final gridPath = Path();
    if (gridCells.isNotEmpty) {
      _appendCellsToPath(
        cells: gridCells,
        hw: hw,
        hh: hh,
        scale: scale,
        cx: cx,
        cy: cy,
        left: left,
        right: right,
        top: top,
        bottom: bottom,
        paths: [gridPath],
      );
    }

    canvas.saveLayer(Offset.zero & size, _layerPaint);
    canvas.drawRect(Offset.zero & size, _fogPaint);
    if (gridCells.isNotEmpty) {
      canvas.drawPath(gridPath, _gridPaint);
    }
    canvas.drawPath(clearPath, _clearPaint);
    canvas.restore();

    // Outlines drawn after restore() so they sit on top of the cleared
    // region rather than being erased by the clear blend.
    canvas.drawPath(outlinePath, _outlinePaint);
  }

  // Projects each cell once and appends the closed polygon to every path
  // in [paths]. Skips cells whose bounding box falls entirely outside the
  // padded viewport.
  void _appendCellsToPath({
    required List<_RenderCell> cells,
    required double hw,
    required double hh,
    required double scale,
    required double cx,
    required double cy,
    required double left,
    required double right,
    required double top,
    required double bottom,
    required List<Path> paths,
  }) {
    for (final cell in cells) {
      final pts = cell.boundary;
      if (pts.isEmpty) continue;

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
      // Antimeridian guard: a cell whose boundary crosses ±180° longitude
      // has two adjacent vertices in lat/lng space at e.g. +179° and -179°,
      // which Mercator projects to mx ≈ 1 and mx ≈ 0 — opposite edges of
      // the world. Drawing the polygon then produces a horizontal stripe
      // across the screen. Detect it via the projected x-span: a normal
      // cell occupies a small fraction of the world width, so any cell
      // whose span exceeds half the world width is wrapping. At resolutions
      // where this matters there are 1–2 such cells globally, all in the
      // Pacific — losing them visually is acceptable.
      if (maxX - minX > scale * 0.5) continue;
      if (maxX < left || minX > right || maxY < top || minY > bottom) continue;

      for (final path in paths) {
        path.moveTo(projected[0].dx, projected[0].dy);
        for (var i = 1; i < projected.length; i++) {
          path.lineTo(projected[i].dx, projected[i].dy);
        }
        path.close();
      }
    }
  }

  @override
  bool shouldRepaint(_FogOfWarPainter old) => false;
}
