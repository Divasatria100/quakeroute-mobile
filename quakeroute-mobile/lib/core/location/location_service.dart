import 'package:geolocator/geolocator.dart';

import '../../core/models/hazard.dart';

/// Thin wrapper around geolocator for FR-001 (display user location).
/// Never throws — returns null when permission is missing/denied or the
/// service is off; callers fall back to the default map view.
class LocationService {
  const LocationService();

  Future<LatLng?> getCurrentLocationOrNull() async {
    try {
      final permission = await Geolocator.checkPermission();
      var resolved = permission;
      if (resolved == LocationPermission.denied ||
          resolved == LocationPermission.deniedForever) {
        resolved = await Geolocator.requestPermission();
      }
      if (resolved == LocationPermission.denied ||
          resolved == LocationPermission.deniedForever ||
          !await Geolocator.isLocationServiceEnabled()) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      // Permission denied, service off, or platform channel unavailable —
      // the map simply stays on its default view.
      return null;
    }
  }
}
