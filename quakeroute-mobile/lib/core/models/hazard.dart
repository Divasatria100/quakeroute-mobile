import 'enums.dart';

/// Read-only DTO — mirror backend structure (api-specification.md §4).
/// Mobile never computes severity/confidence/cost; only displays backend values.
class Hazard {
  const Hazard({
    required this.id,
    required this.type,
    required this.severity,
    required this.confidence,
    required this.roadImpact,
    required this.status,
    required this.location,
    required this.source,
    required this.timestamp,
    this.roadSegmentId,
    this.evidence,
    this.conflictingWith = const [],
  });

  final String id;
  final HazardType type;
  final Severity severity;
  final double confidence;
  final RoadImpact roadImpact;
  final HazardStatus status;
  final LatLng location;
  final String? roadSegmentId;
  final HazardSource source;
  final DateTime timestamp;
  final HazardEvidence? evidence;
  final List<String> conflictingWith;

  factory Hazard.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>;
    return Hazard(
      id: json['hazard_id'] as String,
      type: HazardType.fromApi(json['type'] as String),
      severity: Severity.fromApi(json['severity'] as String),
      confidence: (json['confidence'] as num).toDouble(),
      roadImpact: RoadImpact.fromApi(json['road_impact'] as String),
      status: HazardStatus.fromApi(json['status'] as String),
      location: LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      ),
      roadSegmentId: json['road_segment_id'] as String?,
      source: HazardSource.fromApi(json['source'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      evidence: json['evidence'] != null
          ? HazardEvidence.fromJson(json['evidence'] as Map<String, dynamic>)
          : null,
      conflictingWith:
          (json['conflicting_with'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}

class HazardEvidence {
  const HazardEvidence({this.photoUrl, this.text});

  final String? photoUrl;
  final String? text;

  factory HazardEvidence.fromJson(Map<String, dynamic> json) => HazardEvidence(
    photoUrl: json['photo_url'] as String?,
    text: json['text'] as String?,
  );
}

class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}
