import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/destination.dart';
import '../../../core/models/hazard.dart' show LatLng;
import '../../../core/models/route.dart';
import '../../../core/models/simulation.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/state/ui_state.dart';

class SimulationState {
  const SimulationState({
    this.scenarios = const UiInitial(),
    this.run,
    this.runHandle,
    this.running = false,
    this.error,
    this.selectedScenarioId,
    this.baselineRouteDetail,
    this.riskAwareRouteDetail,
    this.destinations = const UiInitial(),
    this.selectedDestinationId,
    this.simulationCenter = const LatLng(-6.2, 106.8),
    this.seed = 42,
    this.radiusM = 1500,
    this.locationConfirmed = false,
  });

  final UiState<List<SimulationScenario>> scenarios;
  final SimulationRun? run;
  final SimulationRunHandle? runHandle;
  final bool running;
  final String? error;
  final String? selectedScenarioId;

  /// Full route details (with geometry) fetched after run completes.
  /// Used exclusively for map polylines — never global hazard state.
  final QuakeRoute? baselineRouteDetail;
  final QuakeRoute? riskAwareRouteDetail;

  /// Destinations for simulation — distance computed from simulationCenter,
  /// never device GPS (demo deterministic).
  final UiState<List<Destination>> destinations;
  final String? selectedDestinationId;

  /// Crosshair-based simulation center — source of truth for synthetic generation.
  final LatLng simulationCenter;
  final int seed;
  final int radiusM;
  final bool locationConfirmed;

  /// Default center (initial viewport) — not a fixed simulation location.
  static const defaultSimulationCenter = LatLng(-6.2, 106.8);

  SimulationState copyWith({
    UiState<List<SimulationScenario>>? scenarios,
    SimulationRun? run,
    bool clearRun = false,
    SimulationRunHandle? runHandle,
    bool clearRunHandle = false,
    bool? running,
    String? Function()? error,
    String? Function()? selectedScenarioId,
    QuakeRoute? baselineRouteDetail,
    bool clearBaselineDetail = false,
    QuakeRoute? riskAwareRouteDetail,
    bool clearRiskAwareDetail = false,
    UiState<List<Destination>>? destinations,
    String? Function()? selectedDestinationId,
    LatLng? simulationCenter,
    int? seed,
    int? radiusM,
    bool? locationConfirmed,
  }) =>
      SimulationState(
        scenarios: scenarios ?? this.scenarios,
        run: clearRun ? null : (run ?? this.run),
        runHandle: clearRunHandle ? null : (runHandle ?? this.runHandle),
        running: running ?? this.running,
        error: error == null ? this.error : error(),
        selectedScenarioId: selectedScenarioId == null
            ? this.selectedScenarioId
            : selectedScenarioId(),
        baselineRouteDetail: clearBaselineDetail
            ? null
            : (baselineRouteDetail ?? this.baselineRouteDetail),
        riskAwareRouteDetail: clearRiskAwareDetail
            ? null
            : (riskAwareRouteDetail ?? this.riskAwareRouteDetail),
        destinations: destinations ?? this.destinations,
        selectedDestinationId: selectedDestinationId == null
            ? this.selectedDestinationId
            : selectedDestinationId(),
        simulationCenter: simulationCenter ?? this.simulationCenter,
        seed: seed ?? this.seed,
        radiusM: radiusM ?? this.radiusM,
        locationConfirmed: locationConfirmed ?? this.locationConfirmed,
      );
}

class SimulationController extends StateNotifier<SimulationState> {
  SimulationController(this._ref) : super(const SimulationState());
  final Ref _ref;
  Timer? _poll;

  Future<void> loadScenarios() async {
    state = state.copyWith(scenarios: const UiLoading());
    try {
      final list = await _ref.read(simulationRepositoryProvider).getScenarios();
      if (!mounted) return;
      state = state.copyWith(
          scenarios: list.isEmpty ? const UiEmpty() : UiSuccess(list));
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(scenarios: UiError(e.toString()));
    }
  }

  Future<void> loadDestinations() async {
    state = state.copyWith(destinations: const UiLoading());
    try {
      final list = await _ref.read(destinationRepositoryProvider).getDestinations();
      if (!mounted) return;
      if (list.isEmpty) {
        state = state.copyWith(destinations: const UiEmpty());
        return;
      }
      state = state.copyWith(
        destinations: UiSuccess(list),
        selectedDestinationId: state.selectedDestinationId == null ? () => list.first.id : null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(destinations: UiError(e.toString()));
    }
  }

  void selectDestination(String destinationId) {
    state = state.copyWith(selectedDestinationId: () => destinationId);
  }

  void selectCenter(LatLng center) {
    // Update center without confirming — map drag.
    state = state.copyWith(simulationCenter: center);
  }

  void confirmLocation() {
    state = state.copyWith(locationConfirmed: true);
  }

  void refreshSimulation() {
    // Keep center, bump seed, clear previous run.
    final newSeed = state.seed + 1;
    state = state.copyWith(
      seed: newSeed,
      clearRun: true,
      clearRunHandle: true,
      clearBaselineDetail: true,
      clearRiskAwareDetail: true,
      error: () => null,
    );
  }

  Future<void> runScenario(String scenarioId) async {
    // Isolation: clear previous run/markers/routes before starting new scenario.
    _poll?.cancel();
    state = state.copyWith(
      running: true,
      clearRun: true,
      clearRunHandle: true,
      clearBaselineDetail: true,
      clearRiskAwareDetail: true,
      error: () => null,
      selectedScenarioId: () => scenarioId,
    );
    try {
      // Crosshair-based simulation origin — never device GPS.
      final center = state.simulationCenter;
      final origin = center;
      final destId = state.selectedDestinationId;
      if (destId == null) {
        // Lazy-load destinations if not yet loaded.
        try {
          final dests =
              await _ref.read(destinationRepositoryProvider).getDestinations();
          if (dests.isEmpty) throw Exception('No destinations');
          if (!mounted) return;
          state = state.copyWith(
            destinations: UiSuccess(dests),
            selectedDestinationId: () => dests.first.id,
          );
        } catch (_) {
          throw Exception('No destination available to run simulation');
        }
      }
      final effectiveDestId = state.selectedDestinationId;
      if (effectiveDestId == null) throw Exception('No destination selected');
      final handle = await _ref.read(simulationRepositoryProvider).runScenario(
            scenarioId: scenarioId,
            origin: origin,
            destinationId: effectiveDestId,
            center: center,
            seed: state.seed,
            radiusM: state.radiusM,
          );
      if (!mounted) return;

      // Backend currently runs synchronously and returns 202 with Completed
      // status + costs. Prefer polling path so we enrich with route geometries.
      state = state.copyWith(runHandle: handle, running: true);

      // If backend already completed, fetch immediately without waiting for poll.
      if (handle.status == 'Completed') {
        await _fetchAndEnrich(handle.runId);
        return;
      }

      _startPoll(handle.runId);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(running: false, error: () => e.toString());
    }
  }

  Future<void> _fetchAndEnrich(String runId) async {
    try {
      final run =
          await _ref.read(simulationRepositoryProvider).getRun(runId);
      if (!mounted) return;

      QuakeRoute? baseline;
      QuakeRoute? riskAware;

      // Enrich with full route geometries via GET /routes/{id} — the only
      // source of polyline coordinates. Do not use global hazard pool.
      if (run.baselineRoute != null) {
        try {
          baseline = await _ref
              .read(routeRepositoryProvider)
              .getRoute(run.baselineRoute!.routeId);
        } catch (_) {}
      }
      if (run.riskAwareRoute != null) {
        try {
          riskAware = await _ref
              .read(routeRepositoryProvider)
              .getRoute(run.riskAwareRoute!.routeId);
        } catch (_) {}
      }

      if (!mounted) return;
      state = state.copyWith(
        run: run,
        baselineRouteDetail: baseline,
        riskAwareRouteDetail: riskAware,
        running: run.isRunning,
      );

      if (!run.isRunning) {
        _poll?.cancel();
      } else {
        _startPoll(runId);
      }
    } catch (e) {
      _poll?.cancel();
      if (!mounted) return;
      state = state.copyWith(running: false, error: () => e.toString());
    }
  }

  void _startPoll(String runId) {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _fetchAndEnrich(runId);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}

final simulationControllerProvider =
    StateNotifierProvider<SimulationController, SimulationState>(
        (ref) => SimulationController(ref));
