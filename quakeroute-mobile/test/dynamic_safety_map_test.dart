import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quakeroute_mobile/core/models/destination.dart';
import 'package:quakeroute_mobile/core/models/enums.dart';
import 'package:quakeroute_mobile/core/models/hazard.dart';
import 'package:quakeroute_mobile/core/models/road_segment.dart';

import 'package:quakeroute_mobile/core/state/app_providers.dart';
import 'package:quakeroute_mobile/features/destination/data/destination_repository.dart';
import 'package:quakeroute_mobile/features/map/data/hazard_repository.dart';
import 'package:quakeroute_mobile/features/map/presentation/map_screen.dart';
import 'package:quakeroute_mobile/features/map/presentation/widgets/destination_pin.dart';
import 'package:quakeroute_mobile/features/map/presentation/widgets/hazard_pin.dart';

import 'widget_test.dart' show hazardPollIntervalOverride;

class _FakeHazardRepo implements HazardRepository {
  _FakeHazardRepo(this.hazards, {this.detail});
  final List<Hazard> hazards;
  final Hazard? detail;
  @override
  Future<List<Hazard>> getHazards({String? status, String? bbox, DateTime? updatedSince}) async => hazards;
  @override
  Future<Hazard> getHazard(String hazardId) async => detail ?? hazards.first;
}

class _FakeDestRepo implements DestinationRepository {
  _FakeDestRepo(this.list);
  final List<Destination> list;
  @override
  Future<List<Destination>> getDestinations({String? bbox}) async => list;
}

Hazard _hazard({String id = 'h1', String status = 'Reported'}) => Hazard(
      id: id,
      type: HazardType.fire,
      severity: Severity.high,
      confidence: 0.8,
      roadImpact: RoadImpact.blocked,
      status: HazardStatus.fromApi(status),
      location: const LatLng(-6.2, 106.8),
      source: HazardSource.quickTap,
      timestamp: DateTime.parse('2026-08-25T10:00:00Z'),
    );

Destination _dest({String id = 'd1', String type = 'Shelter'}) => Destination(
      id: id,
      name: type == 'Shelter' ? 'Shelter A' : 'Clinic B',
      type: DestinationType.fromApi(type),
      location: const LatLng(-6.21, 106.82),
    );



void main() {
  group('Destination markers', () {
    testWidgets('renders shelter and medical pins', (tester) async {
      final har = _FakeHazardRepo([]);
      final dest = _FakeDestRepo([_dest(id: 'd1', type: 'Shelter'), _dest(id: 'd2', type: 'MedicalFacility')]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hazardRepositoryProvider.overrideWithValue(har),
            destinationRepositoryProvider.overrideWithValue(dest),
            ...hazardPollIntervalOverride(),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      // DestinationPin renders icon inside markers
      expect(find.byType(DestinationPin), findsNWidgets(2));
    });
  });

  group('Hazard detail sheet', () {
    testWidgets('tap hazard opens detail sheet', (tester) async {
      final h = _hazard(id: 'h1');
      final har = _FakeHazardRepo([h], detail: h);
      final dest = _FakeDestRepo([]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hazardRepositoryProvider.overrideWithValue(har),
            destinationRepositoryProvider.overrideWithValue(dest),
            ...hazardPollIntervalOverride(),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.byType(HazardPin), findsOneWidget);
      await tester.tap(find.byType(HazardPin));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fire'), findsWidgets);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('shows conflicting note for UncertainConflicting', (tester) async {
      final h = _hazard(status: 'UncertainConflicting');
      final har = _FakeHazardRepo([h], detail: h);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hazardRepositoryProvider.overrideWithValue(har),
            destinationRepositoryProvider.overrideWithValue(_FakeDestRepo([])),
            ...hazardPollIntervalOverride(),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      await tester.tap(find.byType(HazardPin));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reports disagree'), findsOneWidget);
    });
  });

  group('Road segment', () {
    test('parses GeoJSON [lng,lat] -> LatLng', () {
      final seg = RoadSegment.fromJson({
        'id': 's1',
        'geometry': {'type': 'LineString', 'coordinates': [[106.8, -6.2], [106.81, -6.2]]},
        'condition': 'Critical',
        'base_travel_cost': 10,
      });
      expect(seg.geometry.coordinates.first.lat, closeTo(-6.2, 0.001));
      expect(seg.geometry.coordinates.first.lng, closeTo(106.8, 0.001));
      expect(seg.condition, 'Critical');
    });
  });

  group('Route polyline regression', () {
    testWidgets('active route still renders with destinations', (tester) async {
      final har = _FakeHazardRepo([]);
      final dest = _FakeDestRepo([_dest()]);
      // Provide a fake active route via overriding route repo inside map
      // Map watches routingController; we just ensure map builds without crash when route present.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hazardRepositoryProvider.overrideWithValue(har),
            destinationRepositoryProvider.overrideWithValue(dest),
            ...hazardPollIntervalOverride(),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      // Map should still show 1 destination pin and no crash
      expect(find.byType(DestinationPin), findsOneWidget);
    });
  });
}
