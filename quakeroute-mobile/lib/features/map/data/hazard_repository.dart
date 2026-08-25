import '../../../core/models/enums.dart';
import '../../../core/models/hazard.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Consumes Hazard Retrieval endpoints (api-specification.md §4).
/// Pure API mapping — no filtering/aggregation logic beyond passing
/// documented query parameters through.
class HazardRepository {
  HazardRepository(this._client);

  final ApiClient _client;

  /// GET /hazards?status=&bbox=&updated_since=
  Future<List<Hazard>> getHazards({
    String? status,
    String? bbox,
    DateTime? updatedSince,
  }) async {
    final query = <String, dynamic>{};
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (bbox != null && bbox.isNotEmpty) query['bbox'] = bbox;
    if (updatedSince != null) {
      query['updated_since'] = updatedSince.toUtc().toIso8601String();
    }

    final res = await _client.get(ApiEndpoints.hazards, queryParameters: query);
    final body = res.data as Map<String, dynamic>;
    final items = (body['hazards'] as List<dynamic>? ?? []);
    return items
        .map((e) => Hazard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /hazards/{hazard_id} — includes evidence + conflicting_with (§4.2).
  Future<Hazard> getHazard(String hazardId) async {
    final res = await _client.get(ApiEndpoints.hazardDetail(hazardId));
    return Hazard.fromJson(res.data as Map<String, dynamic>);
  }
}

/// Status values usable with [getHazards] — mirrors enums.dart mapping.
const List<String> knownHazardStatusFilters = [
  'Reported',
  'Confirmed',
  'UncertainConflicting',
];

/// Convenience wrapper so callers can pass a typed enum instead of a raw
/// string while the wire format stays exactly as documented.
String? statusFilterOrNull(HazardStatus? status) => status?.apiValue;
