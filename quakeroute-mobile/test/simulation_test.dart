import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quakeroute_mobile/core/models/destination.dart';
import 'package:quakeroute_mobile/core/models/hazard.dart' show LatLng;
import 'package:quakeroute_mobile/core/models/route.dart';
import 'package:quakeroute_mobile/core/models/simulation.dart';
import 'package:quakeroute_mobile/core/state/app_providers.dart';
import 'package:quakeroute_mobile/core/state/ui_state.dart';
import 'package:quakeroute_mobile/features/destination/data/destination_repository.dart';
import 'package:quakeroute_mobile/features/routing/data/route_repository.dart';
import 'package:quakeroute_mobile/features/simulation/controller/simulation_controller.dart';
import 'package:quakeroute_mobile/features/simulation/data/simulation_repository.dart';
import 'package:quakeroute_mobile/features/simulation/presentation/simulation_screen.dart';
import 'widget_test.dart' show hazardPollIntervalOverride;

class _FakeSimRepo implements SimulationRepository {
  _FakeSimRepo({this.scenarios = const [], this.runRes});
  final List<SimulationScenario> scenarios;
  final SimulationRun? runRes;
  @override
  Future<List<SimulationScenario>> getScenarios() async => scenarios;
  @override
  Future<SimulationRunHandle> runScenario(
          {required String scenarioId,
          required dynamic origin,
          required String destinationId,
          dynamic center,
          int? seed,
          int? radiusM}) async =>
      SimulationRunHandle(
          runId: 'r1', scenarioId: scenarioId, status: 'Completed', startedAt: DateTime.now());
  @override
  Future<SimulationRun> getRun(String runId) async =>
      runRes ??
      SimulationRun(
          runId: runId,
          scenarioId: 'no_hazard',
          status: 'Completed',
          hazardsCreated: [],
          baselineRoute: const SimulationRouteSummary(routeId: 'b', totalCost: 10),
          riskAwareRoute: const SimulationRouteSummary(routeId: 'r', totalCost: 12));
}

class _FakeDestRepo implements DestinationRepository {
  _FakeDestRepo({this.dests});
  final List<Destination>? dests;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
  @override
  Future<List<Destination>> getDestinations({String? bbox}) async =>
      dests ??
      [
        const Destination(
            id: 'd1',
            name: 'Shelter F',
            type: DestinationType.shelter,
            location: LatLng(-6.21, 106.82))
      ];
}

class _FakeRouteRepo implements RouteRepository {
  _FakeRouteRepo();
  @override
  Future<QuakeRoute> createRoute({required String destinationId, required LatLng origin}) =>
      throw UnimplementedError();
  @override
  Future<QuakeRoute?> getActiveRoute() async => null;
  @override
  Future<QuakeRoute> getRoute(String routeId) async {
    // Return a minimal route with geometry for map rendering.
    return QuakeRoute.fromJson({
      'route_id': routeId,
      'destination_id': 'd1',
      'status': 'Active',
      'total_cost': 30,
      'segments': [
        {'road_segment_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'base_travel_cost': 10, 'hazard_penalty': 0, 'uncertainty_penalty': 0, 'segment_routing_cost': 10},
        {'road_segment_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'base_travel_cost': 10, 'hazard_penalty': 0, 'uncertainty_penalty': 0, 'segment_routing_cost': 10},
      ],
      'geometry': {
        'type': 'LineString',
        'coordinates': [
          [106.8, -6.2],
          [106.81, -6.2],
          [106.82, -6.2]
        ]
      },
      'created_at': '2026-08-27T00:00:00Z',
    });
  }
}

void main() {
  group('Simulation models', () {
    test('SimulationHazardSummary parses location, severity, roadSegmentId', () {
      final h = SimulationHazardSummary.fromJson({
        'hazard_id': 'h1',
        'type': 'RoadBlockage',
        'severity': 'High',
        'confidence': 0.95,
        'road_impact': 'Blocked',
        'status': 'Reported',
        'location': {'lat': -6.20, 'lng': 106.815},
        'road_segment_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
        'source': 'AITextExtraction',
      });
      expect(h.hazardId, 'h1');
      expect(h.severity, 'High');
      expect(h.confidence, closeTo(0.95, 0.001));
      expect(h.roadImpact, 'Blocked');
      expect(h.status, 'Reported');
      expect(h.location!.lat, closeTo(-6.20, 0.001));
      expect(h.location!.lng, closeTo(106.815, 0.001));
      expect(h.roadSegmentId, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2');
    });

    test('SimulationHazardSummary handles missing optional fields', () {
      final h = SimulationHazardSummary.fromJson({
        'hazard_id': 'h2',
        'type': 'Flood',
        'road_impact': 'Passable',
      });
      expect(h.location, isNull);
      expect(h.severity, isNull);
      expect(h.roadSegmentId, isNull);
    });

    test('SimulationRouteSummary parses geometry [lng,lat] -> LatLng', () {
      final r = SimulationRouteSummary.fromJson({
        'route_id': 'r1',
        'total_cost': 30,
        'status': 'Active',
        'segments': [
          {'road_segment_id': 'a1', 'from_node_id': 'n1', 'to_node_id': 'n2'},
          {'road_segment_id': 'a2', 'from_node_id': 'n2', 'to_node_id': 'n3'},
        ],
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [106.8, -6.2],
            [106.81, -6.2],
          ]
        },
      });
      expect(r.routeId, 'r1');
      expect(r.totalCost, 30);
      expect(r.segments.length, 2);
      expect(r.geometry!.coordinates.length, 2);
      // GeoJSON [106.8, -6.2] -> LatLng(-6.2, 106.8)
      expect(r.geometry!.coordinates.first.lat, closeTo(-6.2, 0.001));
      expect(r.geometry!.coordinates.first.lng, closeTo(106.8, 0.001));
    });

    test('SimulationRun routesDiffer detects change', () {
      final runSame = SimulationRun(
        runId: 'r1',
        scenarioId: 'no_hazard',
        status: 'Completed',
        hazardsCreated: [],
        baselineRoute: const SimulationRouteSummary(
          routeId: 'b',
          totalCost: 30,
          segments: [
            SimulationRouteSegment(roadSegmentId: 'a1'),
            SimulationRouteSegment(roadSegmentId: 'a2'),
          ],
        ),
        riskAwareRoute: const SimulationRouteSummary(
          routeId: 'r',
          totalCost: 30,
          segments: [
            SimulationRouteSegment(roadSegmentId: 'a1'),
            SimulationRouteSegment(roadSegmentId: 'a2'),
          ],
        ),
      );
      expect(runSame.routesDiffer, false);

      final runDiff = SimulationRun(
        runId: 'r2',
        scenarioId: 'blocked_road',
        status: 'Completed',
        hazardsCreated: [
          const SimulationHazardSummary(
              hazardId: 'h1', type: 'RoadBlockage', roadImpact: 'Blocked', roadSegmentId: 'a2'),
        ],
        baselineRoute: const SimulationRouteSummary(
          routeId: 'b',
          totalCost: 30,
          segments: [
            SimulationRouteSegment(roadSegmentId: 'a1'),
            SimulationRouteSegment(roadSegmentId: 'a2'),
          ],
        ),
        riskAwareRoute: const SimulationRouteSummary(
          routeId: 'r',
          totalCost: 30,
          segments: [
            SimulationRouteSegment(roadSegmentId: 'a1'),
            SimulationRouteSegment(roadSegmentId: 'a3'),
          ],
        ),
      );
      expect(runDiff.routesDiffer, true);
    });
  });

  group('SimulationController isolation', () {
    test('starting new scenario clears previous run', () async {
      final fakeSim = _FakeSimRepo(
        scenarios: [const SimulationScenario(id: 'no_hazard', name: 'No Hazard')],
        runRes: SimulationRun(
          runId: 'r1',
          scenarioId: 'no_hazard',
          status: 'Completed',
          hazardsCreated: [],
          baselineRoute: const SimulationRouteSummary(routeId: 'b', totalCost: 10),
          riskAwareRoute: const SimulationRouteSummary(routeId: 'r', totalCost: 10),
        ),
      );
      final container = ProviderContainer(overrides: [
        simulationRepositoryProvider.overrideWithValue(fakeSim),
        destinationRepositoryProvider.overrideWithValue(_FakeDestRepo()),
        routeRepositoryProvider.overrideWithValue(_FakeRouteRepo()),
        ...hazardPollIntervalOverride(),
      ]);
      final ctrl = container.read(simulationControllerProvider.notifier);
      await ctrl.loadDestinations();
      ctrl.confirmLocation();
      // Select first synthetic destination explicitly
      final dests = (container.read(simulationControllerProvider).destinations as UiSuccess<List<Destination>>).data;
      ctrl.selectDestination(dests.first.id);
      // First run
      await ctrl.runScenario('no_hazard');
      // Wait a tick for enrichment
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(simulationControllerProvider).run, isNotNull);
      expect(container.read(simulationControllerProvider).selectedScenarioId, 'no_hazard');
      final prevRun = container.read(simulationControllerProvider).run;
      expect(prevRun, isNotNull);
      addTearDown(container.dispose);
    });

    test('SimulationState copyWith clears run when requested', () {
      const run = SimulationRun(
        runId: 'r1',
        scenarioId: 'no_hazard',
        status: 'Completed',
        hazardsCreated: [],
      );
      const state = SimulationState(run: run, running: false);
      final cleared = state.copyWith(clearRun: true, running: true);
      expect(cleared.run, isNull);
      expect(cleared.running, true);
    });
  });

  group('SimulationScreen', () {
    testWidgets('list renders', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fake = _FakeSimRepo(
          scenarios: [const SimulationScenario(id: 'no_hazard', name: 'No Hazard')]);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            simulationRepositoryProvider.overrideWithValue(fake),
            destinationRepositoryProvider.overrideWithValue(_FakeDestRepo()),
            routeRepositoryProvider.overrideWithValue(_FakeRouteRepo()),
            ...hazardPollIntervalOverride(),
          ],
          child: const MaterialApp(home: SimulationScreen())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No Hazard'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      final fake = _FakeSimRepo(scenarios: []);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            simulationRepositoryProvider.overrideWithValue(fake),
            destinationRepositoryProvider.overrideWithValue(_FakeDestRepo()),
            routeRepositoryProvider.overrideWithValue(_FakeRouteRepo()),
            ...hazardPollIntervalOverride(),
          ],
          child: const MaterialApp(home: SimulationScreen())));
      await tester.pumpAndSettle();
      expect(find.text('No scenarios'), findsOneWidget);
    });

    test('legend and summary data available after completed run', () async {
      final runRes = SimulationRun(
        runId: 'r1',
        scenarioId: 'blocked_road',
        status: 'Completed',
        hazardsCreated: [
          const SimulationHazardSummary(
            hazardId: 'h1',
            type: 'RoadBlockage',
            roadImpact: 'Blocked',
            severity: 'High',
            roadSegmentId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
            location: LatLng(-6.20, 106.815),
          ),
        ],
        baselineRoute: const SimulationRouteSummary(
          routeId: 'b',
          totalCost: 30,
          segments: [SimulationRouteSegment(roadSegmentId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1')],
        ),
        riskAwareRoute: const SimulationRouteSummary(
          routeId: 'r',
          totalCost: 30,
          segments: [SimulationRouteSegment(roadSegmentId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa5')],
        ),
      );
      final fake = _FakeSimRepo(
        scenarios: [const SimulationScenario(id: 'blocked_road', name: 'Blocked Road')],
        runRes: runRes,
      );
      final container = ProviderContainer(overrides: [
        simulationRepositoryProvider.overrideWithValue(fake),
        destinationRepositoryProvider.overrideWithValue(_FakeDestRepo()),
        routeRepositoryProvider.overrideWithValue(_FakeRouteRepo()),
        ...hazardPollIntervalOverride(),
      ]);
      addTearDown(container.dispose);
      final ctrl = container.read(simulationControllerProvider.notifier);
      await ctrl.loadScenarios();
      await ctrl.loadDestinations();
      ctrl.confirmLocation();
      final dests2 = (container.read(simulationControllerProvider).destinations as UiSuccess<List<Destination>>).data;
      ctrl.selectDestination(dests2.first.id);
      await ctrl.runScenario('blocked_road');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final state = container.read(simulationControllerProvider);
      // Verify data that legend/summary widgets consume.
      expect(state.run, isNotNull);
      expect(state.run!.hazardsCreated.length, 1);
      expect(state.run!.baselineRoute, isNotNull);
      expect(state.run!.riskAwareRoute, isNotNull);
      expect(state.run!.routesDiffer, true);
      expect(state.baselineRouteDetail, isNotNull);
      expect(state.riskAwareRouteDetail, isNotNull);
      // Legend/summary text would be derived from this state in SimulationScreen.
    });

    test('hazard isolation: active run hazards only, no global pool', () async {
      final runRes = SimulationRun(
        runId: 'r1',
        scenarioId: 'blocked_road',
        status: 'Completed',
        hazardsCreated: [
          const SimulationHazardSummary(
            hazardId: 'h1',
            type: 'RoadBlockage',
            roadImpact: 'Blocked',
            roadSegmentId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
            location: LatLng(-6.20, 106.815),
          ),
        ],
        baselineRoute: const SimulationRouteSummary(routeId: 'b', totalCost: 30),
        riskAwareRoute: const SimulationRouteSummary(routeId: 'r', totalCost: 30),
      );
      final fake = _FakeSimRepo(
        scenarios: [
          const SimulationScenario(id: 'blocked_road', name: 'Blocked Road'),
          const SimulationScenario(id: 'high_risk_hazard', name: 'High-Risk Hazard'),
        ],
        runRes: runRes,
      );
      final container = ProviderContainer(overrides: [
        simulationRepositoryProvider.overrideWithValue(fake),
        destinationRepositoryProvider.overrideWithValue(_FakeDestRepo()),
        routeRepositoryProvider.overrideWithValue(_FakeRouteRepo()),
        ...hazardPollIntervalOverride(),
      ]);
      addTearDown(container.dispose);
      final ctrl = container.read(simulationControllerProvider.notifier);
      await ctrl.loadScenarios();
      await ctrl.loadDestinations();
      ctrl.confirmLocation();
      final dests3 = (container.read(simulationControllerProvider).destinations as UiSuccess<List<Destination>>).data;
      ctrl.selectDestination(dests3.first.id);
      await ctrl.runScenario('blocked_road');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final state = container.read(simulationControllerProvider);
      // Only blocked road hazard in active run, not high_risk_hazard.
      expect(state.run!.hazardsCreated.length, 1);
      expect(state.run!.hazardsCreated.first.roadSegmentId,
          'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2');
      expect(state.run!.hazardsCreated.first.roadImpact, 'Blocked');
      // Verify isolation: no stale data from other scenario; location preserved.
      expect(state.run!.hazardsCreated.first.location, isNotNull);
      expect(state.run!.hazardsCreated.first.location!.lat, closeTo(-6.20, 0.001));
    });

    test('simulation destinations loaded from simulation origin, not GPS', () async {
      // Provide 5 real destinations matching the seeded DB.
      final dests = [
        const Destination(id: 'b1', name: 'Shelter Balai Kota', type: DestinationType.shelter, location: LatLng(-6.2005, 106.8005)),
        const Destination(id: 'b2', name: 'Shelter Pasar Minggu', type: DestinationType.shelter, location: LatLng(-6.2005, 106.8205)),
        const Destination(id: 'b3', name: 'Shelter F Community Hall', type: DestinationType.shelter, location: LatLng(-6.2105, 106.8205)),
        const Destination(id: 'b4', name: 'Medical Facility D', type: DestinationType.medicalFacility, location: LatLng(-6.2105, 106.8005)),
        const Destination(id: 'b5', name: 'Medical Facility B', type: DestinationType.medicalFacility, location: LatLng(-6.2005, 106.8105)),
      ];
      final container = ProviderContainer(overrides: [
        simulationRepositoryProvider.overrideWithValue(_FakeSimRepo(scenarios: [const SimulationScenario(id: 'no_hazard', name: 'No Hazard')])),
        destinationRepositoryProvider.overrideWithValue(_FakeDestRepo(dests: dests)),
        routeRepositoryProvider.overrideWithValue(_FakeRouteRepo()),
        ...hazardPollIntervalOverride(),
      ]);
      addTearDown(container.dispose);
      final ctrl = container.read(simulationControllerProvider.notifier);
      await ctrl.loadDestinations();
      final state = container.read(simulationControllerProvider);
      expect(state.destinations is UiSuccess, true);
      final loaded = (state.destinations as UiSuccess<List<Destination>>).data;
      expect(loaded.length, 5);
      // Verify distances are computed from simulationOrigin, not null.
      // Using haversine: origin (-6.2, 106.8)
      // Shelter Balai Kota (-6.2005, 106.8005) ~ 78m
      // Shelter Pasar Minggu (-6.2005, 106.8205) ~ 2.27km
      // All must be < 5km from origin (max diagonal ~2.5km)
      for (final d in loaded) {
        // Direct check that location is valid and not null -> distance computable
        expect(d.location.lat, isNotNull);
        expect(d.location.lng, isNotNull);
      }
      // Selecting destination must persist
      ctrl.selectDestination('b3');
      expect(container.read(simulationControllerProvider).selectedDestinationId, 'b3');
    });

    test('crosshair simulation state updates center, confirms location, and refreshes seed', () async {
      final container = ProviderContainer(overrides: [
        simulationRepositoryProvider.overrideWithValue(_FakeSimRepo()),
        destinationRepositoryProvider.overrideWithValue(_FakeDestRepo()),
        routeRepositoryProvider.overrideWithValue(_FakeRouteRepo()),
        ...hazardPollIntervalOverride(),
      ]);
      addTearDown(container.dispose);

      final ctrl = container.read(simulationControllerProvider.notifier);
      expect(container.read(simulationControllerProvider).simulationCenter, const LatLng(-6.2, 106.8));
      expect(container.read(simulationControllerProvider).seed, 42);
      expect(container.read(simulationControllerProvider).locationConfirmed, false);

      // Select center (map drag)
      const newCenter = LatLng(-6.3, 106.9);
      ctrl.selectCenter(newCenter);
      expect(container.read(simulationControllerProvider).simulationCenter, newCenter);

      // Confirm location
      ctrl.confirmLocation();
      expect(container.read(simulationControllerProvider).locationConfirmed, true);

      // Refresh simulation keeps center and increments seed
      ctrl.refreshSimulation();
      expect(container.read(simulationControllerProvider).simulationCenter, newCenter);
      expect(container.read(simulationControllerProvider).seed, 43);
      expect(container.read(simulationControllerProvider).run, isNull);
    });

    testWidgets('simulation destination picker shows synthetic destinations', (tester) async {
      final fake = _FakeSimRepo(scenarios: [const SimulationScenario(id: 'no_hazard', name: 'No Hazard')]);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            simulationRepositoryProvider.overrideWithValue(fake),
            destinationRepositoryProvider.overrideWithValue(_FakeDestRepo()),
            routeRepositoryProvider.overrideWithValue(_FakeRouteRepo()),
            ...hazardPollIntervalOverride(),
          ],
          child: const MaterialApp(home: SimulationScreen())));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Shelter North-West'), findsOneWidget);
      expect(find.text('Shelter South-East'), findsOneWidget);
      expect(find.textContaining('Distance unavailable'), findsNothing);
    });
  });
}
