import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/location/location_service.dart';
import '../../../core/models/hazard.dart' show LatLng;
import '../../../core/models/simulation.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/state/ui_state.dart';

class SimulationState {
  const SimulationState({this.scenarios = const UiInitial(), this.run, this.runHandle, this.running = false, this.error});
  final UiState<List<SimulationScenario>> scenarios;
  final SimulationRun? run;
  final SimulationRunHandle? runHandle;
  final bool running;
  final String? error;
  SimulationState copyWith({UiState<List<SimulationScenario>>? scenarios, SimulationRun? run, SimulationRunHandle? runHandle, bool? running, String? Function()? error}) =>
      SimulationState(scenarios: scenarios ?? this.scenarios, run: run ?? this.run, runHandle: runHandle ?? this.runHandle, running: running ?? this.running, error: error == null ? this.error : error());
}

class SimulationController extends StateNotifier<SimulationState> {
  SimulationController(this._ref) : super(const SimulationState());
  final Ref _ref;
  Timer? _poll;
  final LocationService _loc = const LocationService();

  Future<void> loadScenarios() async {
    state = state.copyWith(scenarios: const UiLoading());
    try {
      final list = await _ref.read(simulationRepositoryProvider).getScenarios();
      if (!mounted) return;
      state = state.copyWith(scenarios: list.isEmpty ? const UiEmpty() : UiSuccess(list));
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(scenarios: UiError(e.toString()));
    }
  }

  Future<void> runScenario(String scenarioId) async {
    state = state.copyWith(running: true, error: () => null);
    try {
      // Need origin and destination — pick first destination if available, else use default
      LatLng origin = (await _loc.getCurrentLocationOrNull()) ?? const LatLng(-6.2, 106.8);
      // fetch destinations to get an id
      String destId;
      try {
        final dests = await _ref.read(destinationRepositoryProvider).getDestinations();
        destId = dests.first.id;
      } catch (_) {
        throw Exception('No destination available to run simulation');
      }
      final handle = await _ref.read(simulationRepositoryProvider).runScenario(scenarioId: scenarioId, origin: origin, destinationId: destId);
      if (!mounted) return;
      state = state.copyWith(runHandle: handle, running: true);
      _startPoll(handle.runId);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(running: false, error: () => e.toString());
    }
  }

  void _startPoll(String runId) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final run = await _ref.read(simulationRepositoryProvider).getRun(runId);
        if (!mounted) return;
        state = state.copyWith(run: run);
        if (run.status != 'Running') {
          _poll?.cancel();
          state = state.copyWith(running: false);
        }
      } catch (e) {
        _poll?.cancel();
        if (!mounted) return;
        state = state.copyWith(running: false, error: () => e.toString());
      }
    });
  }

  @override
  void dispose() { _poll?.cancel(); super.dispose(); }
}

final simulationControllerProvider = StateNotifierProvider<SimulationController, SimulationState>((ref) => SimulationController(ref));
