import 'package:dio/dio.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/hazard.dart';
import '../../../core/models/hazard_suggestion.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Consumes Hazard Reporting + Suggestion endpoints (api-specification.md §3).
///
/// Boundary: this class sends raw user input only — classification,
/// extraction, severity/confidence assignment all happen backend-side.
class HazardReportRepository {
  HazardReportRepository(this._client);

  final ApiClient _client;

  Map<String, dynamic> _locationPayload(LatLng location) =>
      {'lat': location.lat, 'lng': location.lng};

  /// POST /hazard-reports/photo (§3.1) — multipart upload; returns the
  /// pending AI suggestion awaiting user confirm/reject.
  Future<HazardSuggestion> submitPhoto({
    required String photoPath,
    required LatLng location,
    String? note,
  }) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(photoPath),
      'location[lat]': location.lat,
      'location[lng]': location.lng,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final res = await _client.post(ApiEndpoints.photoReport, data: form);
    return HazardSuggestion.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /hazard-suggestions/{id}/confirm (§3.2).
  /// `edits` keys are limited to type/severity/road_impact per contract;
  /// confidence is never editable client-side.
  Future<Hazard> confirmSuggestion(
    String suggestionId, {
    Map<String, String>? edits,
  }) async {
    final res = await _client.post(
      ApiEndpoints.confirmSuggestion(suggestionId),
      data: {
        if (edits != null && edits.isNotEmpty) 'edits': edits,
      },
    );
    return Hazard.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /hazard-suggestions/{id}/reject (§3.3).
  Future<void> rejectSuggestion(String suggestionId) async {
    await _client.post(ApiEndpoints.rejectSuggestion(suggestionId));
  }

  /// POST /hazard-reports/text (§3.4). Direct-to-dataset per SRS/API
  /// (CONFLICT-01 decision) — no confirmation step. One report may yield
  /// zero or more hazards.
  Future<List<Hazard>> submitText({
    required String text,
    required LatLng location,
  }) async {
    final res = await _client.post(
      ApiEndpoints.textReport,
      data: {
        'text': text,
        'location': _locationPayload(location),
      },
    );
    final body = res.data as Map<String, dynamic>;
    final items = (body['hazards'] as List<dynamic>? ?? []);
    return items
        .map((e) => Hazard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /hazard-reports/quick (§3.5).
  Future<Hazard> submitQuick({
    required HazardType type,
    required LatLng location,
  }) async {
    final res = await _client.post(
      ApiEndpoints.quickReport,
      data: {
        'type': type.apiValue,
        'location': _locationPayload(location),
      },
    );
    return Hazard.fromJson(res.data as Map<String, dynamic>);
  }
}
