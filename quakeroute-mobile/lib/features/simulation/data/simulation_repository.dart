import '../../../core/models/hazard.dart';
import '../../../core/models/simulation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Consumes Emergency Simulation endpoints (api-specification.md §8).
/// Scenario execution and baseline/risk-aware comparison happen entirely
/// backend-side; mobile only triggers, polls, and displays.
class SimulationRepository {
  SimulationRepository(this._client);

  final ApiClient _client;

  /// GET /simulation/scenarios (§8.1) — the six controlled MVP scenarios.
  Future<List<SimulationScenario>> getScenarios() async {
    final res = await _client.get(ApiEndpoints.simulationScenarios);
    final body = res.data as Map<String, dynamic>;
    final items = (body['scenarios'] as List<dynamic>? ?? []);
    return items
        .map((e) => SimulationScenario.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /simulation/scenarios/{scenario_id}/run (§8.2) — returns a 202
  /// handle; results arrive later via [getRun].
  Future<SimulationRunHandle> runScenario({
    required String scenarioId,
    required LatLng origin,
    required String destinationId,
  }) async {
    final res = await _client.post(
      ApiEndpoints.simulationRunScenario(scenarioId),
      data: {
        'origin': {'lat': origin.lat, 'lng': origin.lng},
        'destination_id': destinationId,
      },
    );
    return SimulationRunHandle.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /simulation/runs/{run_id} (§8.3). While `status == Running` the
  /// route summaries are null; caller keeps polling (GAP-05 interval).
  Future<SimulationRun> getRun(String runId) async {
    final res = await _client.get(ApiEndpoints.simulationRun(runId));
    return SimulationRun.fromJson(res.data as Map<String, dynamic>);
  }
}
