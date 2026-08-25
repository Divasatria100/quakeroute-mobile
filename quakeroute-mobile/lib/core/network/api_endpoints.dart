/// Centralized REST endpoint paths — single source of truth for all
/// repositories (api-specification.md §3–§8). Paths are relative to the
/// configured base URL `/api/v1`.
abstract final class ApiEndpoints {
  // Hazard Reporting §3
  static const photoReport = '/hazard-reports/photo';
  static const textReport = '/hazard-reports/text';
  static const quickReport = '/hazard-reports/quick';

  static String confirmSuggestion(String suggestionId) =>
      '/hazard-suggestions/$suggestionId/confirm';
  static String rejectSuggestion(String suggestionId) =>
      '/hazard-suggestions/$suggestionId/reject';

  // Hazard Retrieval §4
  static const hazards = '/hazards';
  static String hazardDetail(String hazardId) => '/hazards/$hazardId';

  // Destinations §5
  static const destinations = '/destinations';

  // Routing & Recalculation §6
  static const routes = '/routes';
  static const activeRoute = '/routes/active';
  static String routeDetail(String routeId) => '/routes/$routeId';

  // Road network
  static const roadSegments = '/road-segments';

  // Emergency Simulation §8
  static const simulationScenarios = '/simulation/scenarios';
  static String simulationRunScenario(String scenarioId) =>
      '/simulation/scenarios/$scenarioId/run';
  static String simulationRun(String runId) => '/simulation/runs/$runId';
}
