import 'enums.dart';
import 'hazard.dart';

/// Photo suggestion — pending confirmation (api-specification.md §3.1).
class HazardSuggestion {
  const HazardSuggestion({
    required this.suggestionId,
    required this.status,
    required this.proposedHazard,
  });

  final String suggestionId;
  final String status;
  final ProposedHazard proposedHazard;

  factory HazardSuggestion.fromJson(Map<String, dynamic> json) =>
      HazardSuggestion(
        suggestionId: json['suggestion_id'] as String,
        status: json['status'] as String,
        proposedHazard: ProposedHazard.fromJson(
          json['proposed_hazard'] as Map<String, dynamic>,
        ),
      );
}

class ProposedHazard {
  const ProposedHazard({
    required this.type,
    required this.severity,
    required this.confidence,
    required this.roadImpact,
    required this.location,
    required this.source,
    this.evidence,
  });

  final HazardType type;
  final Severity severity;
  final double confidence;
  final RoadImpact roadImpact;
  final LatLng location;
  final HazardSource source;
  final HazardEvidence? evidence;

  factory ProposedHazard.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>;
    return ProposedHazard(
      type: HazardType.fromApi(json['type'] as String),
      severity: Severity.fromApi(json['severity'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      roadImpact: RoadImpact.fromApi(json['road_impact'] as String),
      location: LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      ),
      source: HazardSource.fromApi(json['source'] as String),
      evidence: json['evidence'] != null
          ? HazardEvidence.fromJson(json['evidence'] as Map<String, dynamic>)
          : null,
    );
  }
}
