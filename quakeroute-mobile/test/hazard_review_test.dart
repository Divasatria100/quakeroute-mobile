import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quakeroute_mobile/core/models/enums.dart';
import 'package:quakeroute_mobile/core/models/hazard.dart';
import 'package:quakeroute_mobile/core/models/hazard_suggestion.dart';
import 'package:quakeroute_mobile/core/state/app_providers.dart';
import 'package:quakeroute_mobile/features/reporting/data/hazard_report_repository.dart';
import 'package:quakeroute_mobile/features/reporting/photo/controller/photo_report_controller.dart';

class _FakeReviewRepo implements HazardReportRepository {
  Hazard? confirmRes;
  bool rejected = false;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
  @override
  Future<Hazard> confirmSuggestion(String id, {Map<String, String>? edits}) async => confirmRes!;
  @override
  Future<void> rejectSuggestion(String id) async { rejected = true; }
  @override
  Future<HazardSuggestion> submitPhoto({required String photoPath, required LatLng location, String? note}) async => throw UnimplementedError();
}

void main() {
  test('photo controller confirm/reject flows', () async {
    final fake = _FakeReviewRepo();
    fake.confirmRes = Hazard(id: 'h1', type: HazardType.fire, severity: Severity.high, confidence: 0.8, roadImpact: RoadImpact.blocked, status: HazardStatus.reported, location: const LatLng(-6.2, 106.8), source: HazardSource.aiVisionPhoto, timestamp: DateTime.now());
    final container = ProviderContainer(overrides: [hazardReportRepositoryProvider.overrideWithValue(fake)]);
    final ctrl = container.read(photoReportControllerProvider.notifier);
    // Set suggestion manually via state
    ctrl.state = PhotoReportState(step: PhotoStep.review, suggestion: HazardSuggestion(suggestionId: 's1', status: 'PendingConfirmation', proposedHazard: ProposedHazard(type: HazardType.fire, severity: Severity.high, confidence: 0.8, roadImpact: RoadImpact.blocked, location: const LatLng(-6.2, 106.8), source: HazardSource.aiVisionPhoto)), photoPath: '/tmp/a.jpg');
    await ctrl.confirm();
    expect(container.read(photoReportControllerProvider).step, PhotoStep.success);
    // reject
    ctrl.state = PhotoReportState(step: PhotoStep.review, suggestion: HazardSuggestion(suggestionId: 's2', status: 'PendingConfirmation', proposedHazard: ProposedHazard(type: HazardType.fire, severity: Severity.high, confidence: 0.8, roadImpact: RoadImpact.blocked, location: const LatLng(-6.2, 106.8), source: HazardSource.aiVisionPhoto)), photoPath: '/tmp/a.jpg');
    await ctrl.reject();
    expect(fake.rejected, true);
    addTearDown(container.dispose);
  });
}
