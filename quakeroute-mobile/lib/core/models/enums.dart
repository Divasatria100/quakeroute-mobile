library;

enum HazardType {
  debrisRubble('DebrisRubble'),
  roadBlockage('RoadBlockage'),
  fire('Fire'),
  flood('Flood'),
  electricalHazard('ElectricalHazard'),
  visibleBuildingDamage('VisibleBuildingDamage');

  const HazardType(this.apiValue);
  final String apiValue;

  static HazardType fromApi(String v) => HazardType.values.firstWhere(
    (e) => e.apiValue == v,
    orElse: () => HazardType.debrisRubble,
  );
}

enum Severity {
  low('Low'),
  medium('Medium'),
  high('High');

  const Severity(this.apiValue);
  final String apiValue;

  static Severity fromApi(String v) => Severity.values.firstWhere(
    (e) => e.apiValue == v,
    orElse: () => Severity.low,
  );
}

enum RoadImpact {
  passable('Passable'),
  partiallyBlocked('PartiallyBlocked'),
  blocked('Blocked');

  const RoadImpact(this.apiValue);
  final String apiValue;

  static RoadImpact fromApi(String v) => RoadImpact.values.firstWhere(
    (e) => e.apiValue == v,
    orElse: () => RoadImpact.passable,
  );
}

/// Status TBD — minimal set per srs.md FR-027, database-schema.md §3.
enum HazardStatus {
  reported('Reported'),
  confirmed('Confirmed'),
  uncertainConflicting('UncertainConflicting');

  const HazardStatus(this.apiValue);
  final String apiValue;

  static HazardStatus fromApi(String v) => HazardStatus.values.firstWhere(
    (e) => e.apiValue == v,
    orElse: () => HazardStatus.reported,
  );
}

enum HazardSource {
  aiVisionPhoto('AIVisionPhoto'),
  aiTextExtraction('AITextExtraction'),
  quickTap('QuickTap'),
  aiVoiceExtraction('AIVoiceExtraction');

  const HazardSource(this.apiValue);
  final String apiValue;

  static HazardSource fromApi(String v) => HazardSource.values.firstWhere(
    (e) => e.apiValue == v,
    orElse: () => HazardSource.quickTap,
  );
}

enum RouteStatus {
  active('Active'),
  superseded('Superseded');

  const RouteStatus(this.apiValue);
  final String apiValue;

  static RouteStatus fromApi(String v) => RouteStatus.values.firstWhere(
    (e) => e.apiValue == v,
    orElse: () => RouteStatus.active,
  );
}
