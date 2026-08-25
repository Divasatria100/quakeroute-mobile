import 'dart:math' as math;

/// Haversine great-circle distance — presentation-only transform for the
/// destination card (confirmed decision GAP-03; NOT business logic).
double haversineDistanceKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0; // Earth mean radius, km
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Human-readable distance label: meters below 1 km, else km with one
/// decimal. Display formatting only.
String formatDistanceKm(double km) {
  if (km < 1) {
    return '${(km * 1000).round()} m';
  }
  return '${km.toStringAsFixed(1)} km';
}

double _rad(double deg) => deg * math.pi / 180.0;
