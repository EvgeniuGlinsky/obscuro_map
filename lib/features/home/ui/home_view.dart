import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HomeView extends StatelessWidget {
  final TileLayer map;

  const HomeView({
    super.key,
    required this.map,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(50.4501, 30.5234),
        initialZoom: 13.0,
      ),
      children: [map],
    );
  }
}
