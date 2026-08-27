import 'hazard.dart';
import 'route.dart';

/// Emergency Simulation DTOs — mirrors api-specification.md §8.
/// Backend is source of truth; mobile only displays deterministic results.
class SimulationScenario {
  const SimulationScenario({required this.id, required this.name});

  final String id;
  final String name;

  factory SimulationScenario.fromJson(Map<String, dynamic> json) =>
      SimulationScenario(
        id: (json['scenario_id'] ?? json['scenario_key']) as String,
        name: json['name'] as String,
      );
}

/// Handle returned immediately after triggering a run (202 Accepted, §8.2).
class SimulationRunHandle {
  const SimulationRunHandle({
    required this.runId,
    required this.scenarioId,
    required this.status,
    required this.startedAt,
    this.baselineRouteId,
    this.riskAwareRouteId,
    this.baselineCost,
    this.riskAwareCost,
  });

  final String runId;
  final String scenarioId;
  final String status;
  final DateTime startedAt;
  final String? baselineRouteId;
  final String? riskAwareRouteId;
  final double? baselineCost;
  final double? riskAwareCost;

  factory SimulationRunHandle.fromJson(Map<String, dynamic> json) =>
      SimulationRunHandle(
        runId: json['run_id'] as String,
        scenarioId: json['scenario_id'] as String,
        status: json['status'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        baselineRouteId: json['baseline_route_id'] as String?,
        riskAwareRouteId: json['risk_aware_route_id'] as String?,
        baselineCost: (json['baseline_cost'] as num?)?.toDouble(),
        riskAwareCost: (json['risk_aware_cost'] as num?)?.toDouble(),
      );
}

/// Full run result (§8.3). While `status == Running`, both route summaries
/// are null and the client keeps polling.
class SimulationRun {
  const SimulationRun({
    required this.runId,
    required this.scenarioId,
    required this.status,
    required this.hazardsCreated,
    this.baselineRoute,
    this.riskAwareRoute,
    this.origin,
    this.completedAt,
  });

  final String runId;
  final String scenarioId;
  final String status;
  final List<SimulationHazardSummary> hazardsCreated;
  final SimulationRouteSummary? baselineRoute;
  final SimulationRouteSummary? riskAwareRoute;
  final LatLng? origin;
  final DateTime? completedAt;

  bool get isRunning => status == 'Running';
  bool get hasRoutes => baselineRoute != null || riskAwareRoute != null;
  bool get routesDiffer {
    if (baselineRoute == null || riskAwareRoute == null) return false;
    final a = baselineRoute!.segmentIds;
    final b = riskAwareRoute!.segmentIds;
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return true;
    }
    return false;
  }

  factory SimulationRun.fromJson(Map<String, dynamic> json) => SimulationRun(
        runId: json['run_id'] as String,
        scenarioId: json['scenario_id'] as String,
        status: json['status'] as String,
        hazardsCreated:
            (json['hazards_created'] as List<dynamic>? ?? [])
                .map(
                  (e) => SimulationHazardSummary.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList(),
        baselineRoute: json['baseline_route'] == null
            ? null
            : SimulationRouteSummary.fromJson(
                json['baseline_route'] as Map<String, dynamic>,
              ),
        riskAwareRoute: json['risk_aware_route'] == null
            ? null
            : SimulationRouteSummary.fromJson(
                json['risk_aware_route'] as Map<String, dynamic>,
              ),
        origin: json['origin'] == null
            ? null
            : LatLng(
                (json['origin']['lat'] as num).toDouble(),
                (json['origin']['lng'] as num).toDouble(),
              ),
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at'] as String),
      );
}

class SimulationHazardSummary {
  const SimulationHazardSummary({
    required this.hazardId,
    required this.type,
    required this.roadImpact,
    this.severity,
    this.confidence,
    this.status,
    this.location,
    this.roadSegmentId,
    this.source,
  });

  final String hazardId;
  final String type;
  final String roadImpact;
  final String? severity;
  final double? confidence;
  final String? status;
  final LatLng? location;
  final String? roadSegmentId;
  final String? source;

  factory SimulationHazardSummary.fromJson(Map<String, dynamic> json) {
    LatLng? loc;
    final rawLoc = json['location'];
    if (rawLoc is Map<String, dynamic>) {
      final lat = rawLoc['lat'];
      final lng = rawLoc['lng'];
      if (lat is num && lng is num) {
        loc = LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return SimulationHazardSummary(
      hazardId: json['hazard_id'] as String,
      type: json['type'] as String,
      roadImpact: json['road_impact'] as String,
      severity: json['severity'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      status: json['status'] as String?,
      location: loc,
      roadSegmentId: json['road_segment_id'] as String?,
      source: json['source'] as String?,
    );
  }
}

/// Baseline vs risk-aware comparison entry (§8.3).
/// Holds enough to fetch full [QuakeRoute] for geometry when available.
/// Reuses [RouteGeometry] parsing for correct [lng,lat] -> [LatLng] conversion.
class SimulationRouteSummary {
  const SimulationRouteSummary({
    required this.routeId,
    required this.totalCost,
    this.status,
    this.segments = const [],
    this.geometry,
    this.origin,
    this.destinationId,
  });

  final String routeId;
  final double totalCost;
  final String? status;
  final List<SimulationRouteSegment> segments;
  final RouteGeometry? geometry;
  final LatLng? origin;
  final String? destinationId;

  List<String> get segmentIds => segments.map((s) => s.roadSegmentId).toList();

  factory SimulationRouteSummary.fromJson(Map<String, dynamic> json) {
    // Backend routeSummary returns segments as [{road_segment_id, from_node_id, to_node_id}]
    // Route detail (GET /routes/{id}) returns full geometry + more fields.
    // Accept both shapes.
    final segs = <SimulationRouteSegment>[];
    final rawSegs = json['segments'] as List<dynamic>?;
    if (rawSegs != null) {
      for (final e in rawSegs) {
        if (e is Map<String, dynamic>) {
          segs.add(SimulationRouteSegment.fromJson(e));
        }
      }
    }

    RouteGeometry? geom;
    final rawGeom = json['geometry'];
    if (rawGeom is Map<String, dynamic>) {
      geom = RouteGeometry.fromJson(rawGeom);
    }

    LatLng? orig;
    final rawOrigin = json['origin'];
    if (rawOrigin is Map<String, dynamic>) {
      final lat = rawOrigin['lat'];
      final lng = rawOrigin['lng'];
      if (lat is num && lng is num) {
        orig = LatLng(lat.toDouble(), lng.toDouble());
      }
    }

    return SimulationRouteSummary(
      routeId: json['route_id'] as String,
      totalCost: (json['total_cost'] as num).toDouble(),
      status: json['status'] as String?,
      segments: segs,
      geometry: geom,
      origin: orig,
      destinationId: json['destination_id'] as String?,
    );
  }

  /// Enrich this summary with a full QuakeRoute (geometry + full segment costs).
  SimulationRouteSummary withQuakeRoute(QuakeRoute r) => SimulationRouteSummary(
        routeId: r.id,
        totalCost: r.totalCost,
        status: r.status.apiValue,
        segments: r.segments
            .map((s) => SimulationRouteSegment(
                  roadSegmentId: s.roadSegmentId,
                  fromNodeId: null,
                  toNodeId: null,
                ))
            .toList(),
        geometry: r.geometry,
        origin: r.origin,
        destinationId: r.destinationId,
      );
}

class SimulationRouteSegment {
  const SimulationRouteSegment({
    required this.roadSegmentId,
    this.fromNodeId,
    this.toNodeId,
  });

  final String roadSegmentId;
  final String? fromNodeId;
  final String? toNodeId;

  factory SimulationRouteSegment.fromJson(Map<String, dynamic> json) =>
      SimulationRouteSegment(
        roadSegmentId: json['road_segment_id'] as String,
        fromNodeId: json['from_node_id'] as String?,
        toNodeId: json['to_node_id'] as String?,
      );
}

/// Shared location payload shape used across endpoints (api §3–§8).
typedef ApiLocation = LatLng;
