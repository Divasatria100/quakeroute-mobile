import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quakeroute_mobile/core/models/enums.dart';
import 'package:quakeroute_mobile/core/models/hazard.dart';
import 'package:quakeroute_mobile/core/state/app_providers.dart';
import 'package:quakeroute_mobile/features/reporting/data/hazard_report_repository.dart';
import 'package:quakeroute_mobile/features/reporting/photo/presentation/photo_report_screen.dart';
import 'package:quakeroute_mobile/features/reporting/quick_tap/presentation/quick_report_screen.dart';
import 'package:quakeroute_mobile/features/reporting/text/presentation/text_report_screen.dart';

import 'widget_test.dart' show hazardPollIntervalOverride;

class _FakeQuickRepo implements HazardReportRepository {
  bool called = false;
  HazardType? lastType;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
  @override
  Future<Hazard> submitQuick({required HazardType type, required LatLng location}) async {
    called = true; lastType = type;
    return Hazard(id: 'h1', type: type, severity: Severity.high, confidence: 0.7, roadImpact: RoadImpact.passable, status: HazardStatus.reported, location: location, source: HazardSource.quickTap, timestamp: DateTime.now());
  }
}

void main() {
  group('Hazard Reporting', () {
    testWidgets('Quick report renders 6 categories with active taps', (tester) async {
      final fake = _FakeQuickRepo();
      await tester.pumpWidget(ProviderScope(overrides: [hazardReportRepositoryProvider.overrideWithValue(fake), ...hazardPollIntervalOverride()], child: const MaterialApp(home: QuickReportScreen())));
      await tester.pumpAndSettle();
      expect(find.text('Fire'), findsOneWidget);
      expect(find.text('DebrisRubble'), findsOneWidget);
      expect(find.text('Flood'), findsOneWidget);
      expect(find.text('RoadBlockage'), findsOneWidget);
      await tester.tap(find.text('Fire').first, warnIfMissed: false);
      await tester.pump();
      expect(find.text('Fire'), findsOneWidget);
    });
    testWidgets('Text report validation', (tester) async {
      await tester.pumpWidget(ProviderScope(overrides: [...hazardPollIntervalOverride()], child: const MaterialApp(home: TextReportScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Description cannot be empty.'), findsOneWidget);
    });
    testWidgets('Photo screen renders pick buttons', (tester) async {
      await tester.pumpWidget(ProviderScope(overrides: [...hazardPollIntervalOverride()], child: const MaterialApp(home: PhotoReportScreen())));
      await tester.pumpAndSettle();
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
    });
  });
}
