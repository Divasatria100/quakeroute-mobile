import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quakeroute_mobile/core/models/simulation.dart';
import 'package:quakeroute_mobile/core/state/app_providers.dart';
import 'package:quakeroute_mobile/features/simulation/data/simulation_repository.dart';
import 'package:quakeroute_mobile/features/simulation/presentation/simulation_screen.dart';
import 'widget_test.dart' show hazardPollIntervalOverride;

class _FakeSimRepo implements SimulationRepository {
  // ignore: unused_element_parameter
  _FakeSimRepo({this.scenarios = const [], this.runRes});
  final List<SimulationScenario> scenarios;
  final SimulationRun? runRes;
  @override
  Future<List<SimulationScenario>> getScenarios() async => scenarios;
  @override
  Future<SimulationRunHandle> runScenario({required String scenarioId, required dynamic origin, required String destinationId}) async => SimulationRunHandle(runId: 'r1', scenarioId: scenarioId, status: 'Running', startedAt: DateTime.now());
  @override
  Future<SimulationRun> getRun(String runId) async => runRes ?? SimulationRun(runId: runId, scenarioId: 'no_hazard', status: 'Completed', hazardsCreated: [], baselineRoute: const SimulationRouteSummary(routeId: 'b', totalCost: 10, note: ''), riskAwareRoute: const SimulationRouteSummary(routeId: 'r', totalCost: 12, note: ''));
}

void main() {
  testWidgets('Simulation list renders', (tester) async {
    final fake = _FakeSimRepo(scenarios: [const SimulationScenario(id: 'no_hazard', name: 'No Hazard')]);
    await tester.pumpWidget(ProviderScope(overrides: [simulationRepositoryProvider.overrideWithValue(fake), ...hazardPollIntervalOverride()], child: const MaterialApp(home: SimulationScreen())));
    await tester.pumpAndSettle();
    expect(find.text('No Hazard'), findsOneWidget);
  });
  testWidgets('Simulation empty state', (tester) async {
    final fake = _FakeSimRepo(scenarios: []);
    await tester.pumpWidget(ProviderScope(overrides: [simulationRepositoryProvider.overrideWithValue(fake), ...hazardPollIntervalOverride()], child: const MaterialApp(home: SimulationScreen())));
    await tester.pumpAndSettle();
    expect(find.text('No scenarios'), findsOneWidget);
  });
}
