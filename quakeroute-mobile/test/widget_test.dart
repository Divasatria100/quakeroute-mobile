import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quakeroute_mobile/app.dart';
import 'package:quakeroute_mobile/core/models/hazard.dart';
import 'package:quakeroute_mobile/core/state/app_providers.dart';
import 'package:quakeroute_mobile/features/map/data/hazard_repository.dart';

class _EmptyHazardRepository implements HazardRepository {
  @override
  Future<List<Hazard>> getHazards({
    String? status,
    String? bbox,
    DateTime? updatedSince,
  }) async => [];

  @override
  Future<Hazard> getHazard(String hazardId) => throw UnimplementedError();
}

void main() {
  testWidgets('App boots to Safety Disclaimer, then Dynamic Safety Map', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hazardRepositoryProvider.overrideWithValue(
            _EmptyHazardRepository(),
          ),
          ...hazardPollIntervalOverride(),
        ],
        child: const QuakeRouteApp(),
      ),
    );
    await tester.pumpAndSettle();

    // ui-ux §8.1 — disclaimer is shown once per launch, no skip.
    expect(find.text('Safety Disclaimer'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Dynamic Safety Map'), findsOneWidget);
    // ui-ux §5.1 HUD status chip pattern with the empty/valid dataset.
    expect(find.text('0 active hazards nearby'), findsOneWidget);
  });
}

/// Overrides pollIntervalProvider so the delta-polling timer never fires
/// during the test window.
List<Override> hazardPollIntervalOverride() => [
  pollIntervalProvider.overrideWithValue(const Duration(hours: 1)),
];
