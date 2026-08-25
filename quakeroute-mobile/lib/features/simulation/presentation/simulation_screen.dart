import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/simulation.dart';
import '../../../core/state/ui_state.dart';
import '../../../core/theme/qr_tokens.dart';
import '../../../core/widgets/qr_scaffold.dart';
import '../controller/simulation_controller.dart';

class SimulationScreen extends ConsumerStatefulWidget {
  const SimulationScreen({super.key});
  @override
  ConsumerState<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends ConsumerState<SimulationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(simulationControllerProvider.notifier).loadScenarios());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(simulationControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Simulation')),
      body: Padding(
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        child: _body(state),
      ),
    );
  }

  Widget _body(SimulationState s) {
    final scenariosState = s.scenarios;
    if (scenariosState is UiLoading) return const QRLoadingRow(message: 'Loading scenarios…');
    if (scenariosState is UiError) return QRErrorState(message: (scenariosState as UiError).message, onRetry: () => ref.read(simulationControllerProvider.notifier).loadScenarios());
    if (scenariosState is UiEmpty) return const QREmptyState(message: 'No scenarios', icon: Icons.science_outlined);
    if (scenariosState is UiSuccess<List<SimulationScenario>>) {
      final list = scenariosState.data;
      return ListView(
        children: [
          ...list.map((sc) => Card(
                child: ListTile(
                  title: Text(sc.name),
                  subtitle: Text(sc.id),
                  trailing: s.running ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
                  onTap: s.running ? null : () => ref.read(simulationControllerProvider.notifier).runScenario(sc.id),
                ),
              )),
          if (s.error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(s.error!, style: const TextStyle(color: QRTokens.semanticDanger))),
          if (s.run != null) ...[
            const Divider(height: 32),
            Text('Result: ${s.run!.status}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Hazards: ${s.run!.hazardsCreated.length}'),
            if (s.run!.baselineRoute != null) Text('Baseline cost: ${s.run!.baselineRoute!.totalCost}'),
            if (s.run!.riskAwareRoute != null) Text('Risk-aware cost: ${s.run!.riskAwareRoute!.totalCost}'),
            if (s.run!.baselineRoute != null && s.run!.riskAwareRoute != null)
              Text('Delta: ${(s.run!.riskAwareRoute!.totalCost - s.run!.baselineRoute!.totalCost).toStringAsFixed(1)}'),
          ] else if (s.runHandle != null) ...[
            const SizedBox(height: 16),
            Text('Running ${s.runHandle!.scenarioId}… (${s.runHandle!.runId.substring(0, 8)})'),
            const LinearProgressIndicator(),
          ],
        ],
      );
    }
    return const SizedBox();
  }
}
