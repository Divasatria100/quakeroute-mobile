import '../../../core/models/destination.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Consumes Destinations endpoint (api-specification.md §5).
class DestinationRepository {
  DestinationRepository(this._client);

  final ApiClient _client;

  /// GET /destinations?bbox= (bbox optional per §5.1).
  Future<List<Destination>> getDestinations({String? bbox}) async {
    final query = <String, dynamic>{};
    if (bbox != null && bbox.isNotEmpty) query['bbox'] = bbox;

    final res = await _client.get(
      ApiEndpoints.destinations,
      queryParameters: query,
    );
    final body = res.data as Map<String, dynamic>;
    final items = (body['destinations'] as List<dynamic>? ?? []);
    return items
        .map((e) => Destination.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
