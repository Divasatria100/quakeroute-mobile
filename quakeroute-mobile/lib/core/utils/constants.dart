/// App-wide constants — no business logic.
abstract final class AppConstants {
  static const String appName = 'QuakeRoute';
  static const String apiBasePath = '/api/v1';

  // Quick-tap categories — prd.md §12 (6 MVP hazard types)
  static const List<String> hazardCategories = [
    'DebrisRubble',
    'RoadBlockage',
    'Fire',
    'Flood',
    'ElectricalHazard',
    'VisibleBuildingDamage',
  ];
}
