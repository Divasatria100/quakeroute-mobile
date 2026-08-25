import 'hazard.dart';

class RoadSegment {
  const RoadSegment({
    required this.id,
    required this.geometry,
    required this.condition,
    required this.baseTravelCost,
  });

  final String id;
  final RoadSegmentGeometry geometry;
  final String condition;
  final double baseTravelCost;

  factory RoadSegment.fromJson(Map<String, dynamic> json) {
    final geom = json['geometry'] as Map<String, dynamic>;
    return RoadSegment(
      id: json['id'] as String,
      geometry: RoadSegmentGeometry.fromJson(geom),
      condition: json['condition'] as String,
      baseTravelCost: (json['base_travel_cost'] as num).toDouble(),
    );
  }
}

class RoadSegmentGeometry {
  const RoadSegmentGeometry({required this.type, required this.coordinates});

  final String type;
  final List<LatLng> coordinates;

  factory RoadSegmentGeometry.fromJson(Map<String, dynamic> json) {
    final raw = json['coordinates'] as List<dynamic>? ?? [];
    final coords = <LatLng>[];
    for (final c in raw) {
      if (c is List && c.length >= 2) {
        final lng = (c[0] as num).toDouble();
        final lat = (c[1] as num).toDouble();
        coords.add(LatLng(lat, lng));
      }
    }
    return RoadSegmentGeometry(type: json['type'] as String? ?? 'LineString', coordinates: coords);
  }
}
