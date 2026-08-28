import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/destination.dart';
import '../../../core/models/hazard.dart' show LatLng;
import '../../../core/models/route.dart';
import '../../../core/models/simulation.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/state/ui_state.dart';
import '../support/synthetic_network_generator.dart';

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
    this.confirmedCenter,
    this.previewNetwork,
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

  /// Center that was last confirmed via `Use This Location`.
  /// Used to detect staleness when user pans after confirmation without regenerating.
  final LatLng? confirmedCenter;

  /// Synthetic network generated at last confirmation (for preview routing).
  /// Geographic-fixed until next confirm/refresh.
  final Map<String, dynamic>? previewNetwork;

  /// Default center (initial viewport) — not a fixed simulation location.
  static const defaultSimulationCenter = LatLng(-6.2, 106.8);

  /// True when location was confirmed but simulationCenter has drifted.
  bool get isCenterStale {
    if (!locationConfirmed) return false;
    if (confirmedCenter == null) return false;
    return confirmedCenter!.lat != simulationCenter.lat ||
        confirmedCenter!.lng != simulationCenter.lng;
  }

  /// Preview polyline following synthetic network from simulationCenter to selected destination.
  /// Returns null if no selection or no preview network.
  List<LatLng>? get previewRoute {
    if (selectedDestinationId == null) return null;
    if (previewNetwork == null) return null;
    if (destinations is! UiSuccess<List<Destination>>) return null;
    final dests = (destinations as UiSuccess<List<Destination>>).data;
    Destination? selected;
    for (final d in dests) {
      if (d.id == selectedDestinationId) {
        selected = d;
        break;
      }
    }
    if (selected == null) return null;
    final nodes = previewNetwork!['nodes'] as List<Map<String, dynamic>>;
    final segments = previewNetwork!['segments'] as List<Map<String, dynamic>>;
    // Use current simulationCenter as origin (reactive to pan)
    return SyntheticNetworkGenerator.shortestPathWithCache(
      nodes,
      segments,
      simulationCenter,
      selected.location,
    );
  }

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
    LatLng? confirmedCenter,
    bool clearConfirmedCenter = false,
    Map<String, dynamic>? previewNetwork,
    bool clearPreviewNetwork = false,
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
        confirmedCenter:
            clearConfirmedCenter ? null : (confirmedCenter ?? this.confirmedCenter),
        previewNetwork:
            clearPreviewNetwork ? null : (previewNetwork ?? this.previewNetwork),
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
      final list = _generateSyntheticDestinations(
        state.simulationCenter,
        state.radiusM,
        state.seed,
      );
      if (!mounted) return;
      state = state.copyWith(
        destinations: UiSuccess(list),
        selectedDestinationId: () => null,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(destinations: UiError(e.toString()));
    }
  }

  List<Destination> _generateSyntheticDestinations(LatLng center, int radiusM, int seed) {
    // Use SyntheticNetworkGenerator to stay consistent with backend for preview routing and destination IDs.
    final gen = SyntheticNetworkGenerator.generate(center.lat, center.lng, seed, radiusM);
    final dests = gen['destinations'] as List<Map<String, dynamic>>;
    return dests
        .map((d) => Destination(
              id: d['id'] as String,
              name: d['name'] as String,
              type: DestinationType.fromApi(d['type'] as String),
              location: LatLng(d['lat'] as double, d['lng'] as double),
            ))
        .toList();
  }

  Map<String, dynamic> _generatePreviewNetwork(LatLng center, int radiusM, int seed) {
    final gen = SyntheticNetworkGenerator.generate(center.lat, center.lng, seed, radiusM);
    return {
      'nodes': gen['nodes'],
      'segments': gen['segments'],
    };
  }

  void selectDestination(String destinationId) {
    state = state.copyWith(selectedDestinationId: () => destinationId);
  }

  void selectCenter(LatLng center) {
    // Map pan — update simulationCenter only. Do NOT regenerate destinations.
    // Destination set is geographic-fixed until next explicit generation
    // (confirmLocation / refreshSimulation). This keeps markers from
    // appearing to follow the crosshair.
    // If already confirmed, panning makes center stale and clears selection
    // to avoid showing a selected destination that appears to belong to the new center.
    if (state.simulationCenter.lat == center.lat &&
        state.simulationCenter.lng == center.lng) {
      return;
    }
    final bool wasConfirmed = state.locationConfirmed;
    if (wasConfirmed) {
      // Keep destinations visible but clear stale selection and keep confirmedCenter for stale detection.
      final bool willBeStale = state.confirmedCenter != null &&
          (state.confirmedCenter!.lat != center.lat ||
              state.confirmedCenter!.lng != center.lng);
      if (willBeStale && state.selectedDestinationId != null) {
        state = state.copyWith(
          simulationCenter: center,
          selectedDestinationId: () => null,
        );
      } else {
        state = state.copyWith(simulationCenter: center);
      }
    } else {
      state = state.copyWith(simulationCenter: center);
    }
  }

  void confirmLocation() {
    // Generate fixed destination set around current simulationCenter + seed.
    // Coordinates remain stable until next regeneration (refresh or re-confirm).
    // This is the ONLY place where destinations are (re)generated for a center.
    final list = _generateSyntheticDestinations(
      state.simulationCenter,
      state.radiusM,
      state.seed,
    );
    final previewNet = _generatePreviewNetwork(
      state.simulationCenter,
      state.radiusM,
      state.seed,
    );
    state = state.copyWith(
      locationConfirmed: true,
      confirmedCenter: state.simulationCenter,
      destinations: UiSuccess(list),
      selectedDestinationId: () => null,
      previewNetwork: previewNet,
    );
  }

  void refreshSimulation() {
    // Keep center, bump seed, clear previous run/markers/selection, regenerate.
    final newSeed = state.seed + 1;
    final list = _generateSyntheticDestinations(state.simulationCenter, state.radiusM, newSeed);
    final previewNet = _generatePreviewNetwork(state.simulationCenter, state.radiusM, newSeed);
    state = state.copyWith(
      seed: newSeed,
      destinations: UiSuccess(list),
      selectedDestinationId: () => null,
      locationConfirmed: false,
      clearConfirmedCenter: true,
      clearPreviewNetwork: false,
      previewNetwork: previewNet,
      clearRun: true,
      clearRunHandle: true,
      clearBaselineDetail: true,
      clearRiskAwareDetail: true,
      error: () => null,
      selectedScenarioId: () => null,
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
      // Require explicit destination selection; no silent fallback.
      if (!state.locationConfirmed) {
        throw Exception('Please confirm location first');
      }
      final destId = state.selectedDestinationId;
      if (destId == null) {
        throw Exception('Please select a destination');
      }
      final effectiveDestId = destId;
      final center = state.simulationCenter;
      final origin = center;
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
