import '../../../core/models/road_segment.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class RoadSegmentRepository {
  RoadSegmentRepository(this._client);
  final ApiClient _client;

  Future<List<RoadSegment>> getRoadSegments({String? bbox}) async {
    final q = <String, dynamic>{};
    if (bbox != null && bbox.isNotEmpty) q['bbox'] = bbox;
    final res = await _client.get(ApiEndpoints.roadSegments, queryParameters: q);
    final body = res.data as Map<String, dynamic>;
    final items = (body['data'] as List<dynamic>? ?? []);
    return items.map((e) => RoadSegment.fromJson(e as Map<String, dynamic>)).toList();
  }
}
