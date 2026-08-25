import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quakeroute_mobile/core/models/hazard.dart' show LatLng;
import 'package:quakeroute_mobile/core/models/route.dart';
import 'package:quakeroute_mobile/core/network/api_exception.dart';
import 'package:quakeroute_mobile/core/state/app_providers.dart';
import 'package:quakeroute_mobile/core/state/ui_state.dart';
import 'package:quakeroute_mobile/features/routing/controller/routing_controller.dart';
import 'package:quakeroute_mobile/features/routing/data/route_repository.dart';
import 'package:quakeroute_mobile/features/routing/presentation/routing_screen.dart';
import 'widget_test.dart' show hazardPollIntervalOverride;

class _FakeRouteRepo implements RouteRepository {
  // ignore: unused_element_parameter
  _FakeRouteRepo({this.active, this.error, this.onCreate});
  QuakeRoute? active;
  Object? error;
  Future<QuakeRoute> Function()? onCreate;
  @override
  Future<QuakeRoute> createRoute({required String destinationId, required LatLng origin}) async {
    if (onCreate != null) return onCreate!();
    throw UnimplementedError();
  }

  @override
  Future<QuakeRoute?> getActiveRoute() async {
    if (error != null) throw error!;
    return active;
  }

  @override
  Future<QuakeRoute> getRoute(String routeId) async => active!;
}

Map<String, dynamic> _routeJson({
  String id = 'r1',
  List<List<double>>? coords,
  bool includeGeometry = true,
}) {
  return {
    'route_id': id,
    'destination_id': 'd1',
    'status': 'Active',
    'supersedes_route_id': null,
    'total_cost': 20.5,
    'segments': [
      {'road_segment_id': 'seg-a', 'base_travel_cost': 10, 'hazard_penalty': 0, 'uncertainty_penalty': 0.5, 'segment_routing_cost': 10.5},
      {'road_segment_id': 'seg-b', 'base_travel_cost': 10, 'hazard_penalty': 0, 'uncertainty_penalty': 0, 'segment_routing_cost': 10},
    ],
    'geometry': includeGeometry
        ? {'type': 'LineString', 'coordinates': coords ?? [[106.8, -6.2], [106.81, -6.2], [106.82, -6.2]]}
        : null,
    'created_at': '2026-08-25T10:00:00Z',
  };
}

void main() {
  group('RouteGeometry parsing', () {
    test('parses [lng,lat] into LatLng(lat,lng)', () {
      final r = QuakeRoute.fromJson(_routeJson());
      expect(r.geometry!.type, 'LineString');
      expect(r.geometry!.coordinates.length, 3);
      // GeoJSON [106.8, -6.2] -> LatLng(-6.2,106.8)
      expect(r.geometry!.coordinates.first.lat, closeTo(-6.2, 0.0001));
      expect(r.geometry!.coordinates.first.lng, closeTo(106.8, 0.0001));
      expect(r.hasGeometry, true);
    });

    test('null geometry is handled', () {
      final r = QuakeRoute.fromJson(_routeJson(includeGeometry: false));
      expect(r.geometry, isNull);
      expect(r.hasGeometry, false);
    });

    test('malformed coordinates filtered', () {
      final r = QuakeRoute.fromJson(_routeJson(coords: [[999, 999], [106.8, -6.2]]));
      // 999 invalid lat/lng filtered, only 1 valid remains
      expect(r.geometry!.coordinates.length, 1);
    });

    test('empty coordinates -> empty geometry', () {
      final r = QuakeRoute.fromJson(_routeJson(coords: []));
      expect(r.geometry!.coordinates, isEmpty);
    });
  });

  group('RoutingController', () {
    test('active route success syncs state', () async {
      final fake = _FakeRouteRepo(active: QuakeRoute.fromJson(_routeJson()));
      final container = ProviderContainer(overrides: [routeRepositoryProvider.overrideWithValue(fake)]);
      final ctrl = container.read(routingControllerProvider.notifier);
      await ctrl.loadActive();
      final s = container.read(routingControllerProvider);
      expect(s.routeState is UiSuccess, true);
      addTearDown(container.dispose);
    });

    test('404 no active route -> UiEmpty', () async {
      final fake = _FakeRouteRepo(active: null);
      final container = ProviderContainer(overrides: [routeRepositoryProvider.overrideWithValue(fake)]);
      await container.read(routingControllerProvider.notifier).loadActive();
      expect(container.read(routingControllerProvider).routeState is UiEmpty, true);
      addTearDown(container.dispose);
    });

    test('409 route unavailable mapped correctly', () async {
      final fake = _FakeRouteRepo(error: const ApiException(code: 'UNROUTABLE', message: 'No route', statusCode: 409));
      final container = ProviderContainer(overrides: [routeRepositoryProvider.overrideWithValue(fake)]);
      await container.read(routingControllerProvider.notifier).loadActive();
      final state = container.read(routingControllerProvider).routeState;
      expect(state is UiError, true);
      expect((state as UiError).code, 'ROUTE_UNAVAILABLE');
      addTearDown(container.dispose);
    });
  });

  group('RoutingScreen', () {
    testWidgets('shows loading then success with polyline data', (tester) async {
      final route = QuakeRoute.fromJson(_routeJson());
      final fake = _FakeRouteRepo(active: route);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            routeRepositoryProvider.overrideWithValue(fake),
            ...hazardPollIntervalOverride(),
          ],
          child: const MaterialApp(home: RoutingScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('Why this route?'), findsOneWidget);
      expect(find.textContaining('Total cost'), findsOneWidget);
    });

    testWidgets('shows empty when no active route', (tester) async {
      final fake = _FakeRouteRepo(active: null);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [routeRepositoryProvider.overrideWithValue(fake), ...hazardPollIntervalOverride()],
          child: const MaterialApp(home: RoutingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No active route'), findsOneWidget);
    });

    testWidgets('shows route unavailable on 409', (tester) async {
      final fake = _FakeRouteRepo(error: const ApiException(code: 'UNROUTABLE', message: 'No route', statusCode: 409));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [routeRepositoryProvider.overrideWithValue(fake), ...hazardPollIntervalOverride()],
          child: const MaterialApp(home: RoutingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No feasible route found'), findsOneWidget);
    });
  });
}


