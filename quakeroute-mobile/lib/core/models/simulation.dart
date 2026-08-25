import 'hazard.dart';

/// Emergency Simulation DTOs — mirrors api-specification.md §8.
/// Read-only display data; mobile never evaluates scenario outcomes.
class SimulationScenario {
  const SimulationScenario({required this.id, required this.name});

  final String id;
  final String name;

  factory SimulationScenario.fromJson(Map<String, dynamic> json) =>
      SimulationScenario(
        id: json['scenario_id'] as String,
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
  });

  final String runId;
  final String scenarioId;
  final String status;
  final DateTime startedAt;

  factory SimulationRunHandle.fromJson(Map<String, dynamic> json) =>
      SimulationRunHandle(
        runId: json['run_id'] as String,
        scenarioId: json['scenario_id'] as String,
        status: json['status'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
      );
}

/// Full run result (§8.3). While `status == Running`, both route summaries
/// are null and the client keeps polling (interval per GAP-05 decision).
class SimulationRun {
  const SimulationRun({
    required this.runId,
    required this.scenarioId,
    required this.status,
    required this.hazardsCreated,
    this.baselineRoute,
    this.riskAwareRoute,
    this.completedAt,
  });

  final String runId;
  final String scenarioId;
  final String status;
  final List<SimulationHazardSummary> hazardsCreated;
  final SimulationRouteSummary? baselineRoute;
  final SimulationRouteSummary? riskAwareRoute;
  final DateTime? completedAt;

  bool get isRunning => status == 'Running';

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
  });

  final String hazardId;
  final String type;
  final String roadImpact;

  factory SimulationHazardSummary.fromJson(Map<String, dynamic> json) =>
      SimulationHazardSummary(
        hazardId: json['hazard_id'] as String,
        type: json['type'] as String,
        roadImpact: json['road_impact'] as String,
      );
}

/// Baseline vs risk-aware comparison entry (§8.3).
/// Values displayed verbatim — no client-side cost computation.
class SimulationRouteSummary {
  const SimulationRouteSummary({
    required this.routeId,
    required this.totalCost,
    required this.note,
  });

  final String routeId;
  final double totalCost;
  final String note;

  factory SimulationRouteSummary.fromJson(Map<String, dynamic> json) =>
      SimulationRouteSummary(
        routeId: json['route_id'] as String,
        totalCost: (json['total_cost'] as num).toDouble(),
        note: json['note'] as String? ?? '',
      );
}

/// Shared location payload shape used across endpoints (api §3–§8).
typedef ApiLocation = LatLng;
