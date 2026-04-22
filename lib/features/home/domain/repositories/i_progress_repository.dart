import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract interface class IProgressRepository {
  List<LatLng> load();
  Future<void> save(List<LatLng> points);
}