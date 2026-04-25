import 'package:google_maps_flutter/google_maps_flutter.dart';

sealed class LocationEvent {
  const LocationEvent();
}

final class LocationStarted extends LocationEvent {
  const LocationStarted();
}

/// Removes every tracked point within [radiusMeters] of [center].
/// Does not persist; dispatch [LocationProgressSaved] when the gesture ends.
final class LocationPointsErased extends LocationEvent {
  const LocationPointsErased({required this.center, required this.radiusMeters});
  final LatLng center;
  final double radiusMeters;
}

/// Persists the current in-memory point list to storage.
final class LocationProgressSaved extends LocationEvent {
  const LocationProgressSaved();
}

/// Adds a set of virtual fill points that reveal an enclosed fog region.
final class LocationAreaFilled extends LocationEvent {
  const LocationAreaFilled({required this.fillPoints});
  final List<LatLng> fillPoints;
}

/// Internal: fires when the auth state changes. [uid] is `null` while
/// signed out. Triggers a one-time cloud sync per uid on sign-in.
final class LocationAuthChanged extends LocationEvent {
  const LocationAuthChanged(this.uid);
  final String? uid;
}