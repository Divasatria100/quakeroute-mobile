import 'hazard.dart';

class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
  });

  final String id;
  final String name;
  final DestinationType type;
  final LatLng location;

  factory Destination.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>;
    return Destination(
      id: json['destination_id'] as String,
      name: json['name'] as String,
      type: DestinationType.fromApi(json['type'] as String),
      location: LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      ),
    );
  }
}

enum DestinationType {
  shelter('Shelter'),
  medicalFacility('MedicalFacility');

  const DestinationType(this.apiValue);
  final String apiValue;

  static DestinationType fromApi(String v) => DestinationType.values.firstWhere(
    (e) => e.apiValue == v,
    orElse: () => DestinationType.shelter,
  );
}
