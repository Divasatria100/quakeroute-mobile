import '../../../core/models/hazard.dart';
import '../../../core/models/route.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';

/// Consumes Routing & Recalculation endpoints (api-specification.md §6).
/// The mobile app only sends origin/destination and renders the returned
/// costs — routing decisions are entirely backend-owned.
class RouteRepository {
  RouteRepository(this._client);

  final ApiClient _client;

  /// POST /routes (§6.1) — creates a new route, superseding any active one.
  Future<QuakeRoute> createRoute({
    required String destinationId,
    required LatLng origin,
  }) async {
    final res = await _client.post(
      ApiEndpoints.routes,
      data: {
        'destination_id': destinationId,
        'origin': {'lat': origin.lat, 'lng': origin.lng},
      },
    );
    return QuakeRoute.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /routes/active (§6.3). Returns null on `404 NO_ACTIVE_ROUTE` —
  /// an expected state, not a failure.
  Future<QuakeRoute?> getActiveRoute() async {
    try {
      final res = await _client.get(ApiEndpoints.activeRoute);
      return QuakeRoute.fromJson(res.data as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// GET /routes/{route_id} (§6.2) — includes superseded_by_route_id.
  Future<QuakeRoute> getRoute(String routeId) async {
    final res = await _client.get(ApiEndpoints.routeDetail(routeId));
    return QuakeRoute.fromJson(res.data as Map<String, dynamic>);
  }
}
