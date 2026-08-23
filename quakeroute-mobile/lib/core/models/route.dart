import 'enums.dart';
import 'hazard.dart';

/// Route DTO — mirrors api-specification.md §6.1.
class QuakeRoute {
  const QuakeRoute({
    required this.id,
    required this.destinationId,
    required this.status,
    required this.totalCost,
    required this.segments,
    required this.createdAt,
    this.supersedesRouteId,
    this.supersededByRouteId,
    this.origin,
  });

  final String id;
  final String destinationId;
  final RouteStatus status;
  final String? supersedesRouteId;
  final String? supersededByRouteId;
  final double totalCost;
  final List<RouteSegment> segments;
  final DateTime createdAt;
  final LatLng? origin;

  factory QuakeRoute.fromJson(Map<String, dynamic> json) {
    return QuakeRoute(
      id: json['route_id'] as String,
      destinationId: json['destination_id'] as String,
      status: RouteStatus.fromApi(json['status'] as String),
      supersedesRouteId: json['supersedes_route_id'] as String?,
      supersededByRouteId: json['superseded_by_route_id'] as String?,
      totalCost: (json['total_cost'] as num).toDouble(),
      segments: (json['segments'] as List<dynamic>? ?? [])
          .map((e) => RouteSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class RouteSegment {
  const RouteSegment({
    required this.roadSegmentId,
    required this.baseTravelCost,
    required this.hazardPenalty,
    required this.uncertaintyPenalty,
    required this.segmentRoutingCost,
  });

  final String roadSegmentId;
  final double baseTravelCost;
  final double hazardPenalty;
  final double uncertaintyPenalty;
  final double segmentRoutingCost;

  factory RouteSegment.fromJson(Map<String, dynamic> json) => RouteSegment(
    roadSegmentId: json['road_segment_id'] as String,
    baseTravelCost: (json['base_travel_cost'] as num).toDouble(),
    hazardPenalty: (json['hazard_penalty'] as num).toDouble(),
    uncertaintyPenalty: (json['uncertainty_penalty'] as num).toDouble(),
    segmentRoutingCost: (json['segment_routing_cost'] as num).toDouble(),
  );
}
