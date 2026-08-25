import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/hazard.dart';
import '../../../core/polling/polling_service.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/state/ui_state.dart';
import '../data/hazard_repository.dart';

/// Mutable map-layer state for the Dynamic Safety Map (ui-ux §8.2).
/// Holds the currently known hazards plus refresh bookkeeping.
class HazardMapState {
  const HazardMapState({
    this.hazards = const [],
    this.lastUpdated,
    this.initialState = const UiInitial<List<Hazard>>(),
    this.refreshing = false,
    this.refreshError,
  });

  final List<Hazard> hazards;
  final DateTime? lastUpdated;

  /// Drives the initial loading / error / empty overlay (§8.2 states).
  final UiState<List<Hazard>> initialState;

  /// True while a manual or delta refresh is in flight over existing data.
  final bool refreshing;

  /// Set when a background/manual refresh fails while data is still shown
  /// (map "falls back to last-known cached view", ui-ux §11 row 1).
  final String? refreshError;

  bool get isEmpty => hazards.isEmpty;

  int countWhere(bool Function(Hazard) test) => hazards.where(test).length;

  HazardMapState copyWith({
    List<Hazard>? hazards,
    DateTime? lastUpdated,
    UiState<List<Hazard>>? initialState,
    bool? refreshing,
    String? refreshError,
  }) => HazardMapState(
    hazards: hazards ?? this.hazards,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    initialState: initialState ?? this.initialState,
    refreshing: refreshing ?? this.refreshing,
    refreshError: refreshError,
  );
}

/// Controller for `GET /hazards` consumption:
/// - initial full fetch
/// - manual full refresh
/// - delta polling via `updated_since` (GAP-05 interval), merging by id
///
/// Boundary note: merging API responses into a display list is presentation
/// state management, not risk computation.
class HazardMapController extends StateNotifier<HazardMapState> {
  HazardMapController(this._repo, PollingService polling)
    : _polling = polling,
      super(const HazardMapState());

  final HazardRepository _repo;
  final PollingService _polling;
  bool _disposed = false;

  /// Every Nth poll tick performs a full silent reconcile instead of a
  /// delta fetch (ASUMSI-F: purges server-side deletions; ≈5 min at the
  /// default 20s interval).
  static const int fullReconcileEveryTicks = 15;
  int _tickCount = 0;

  /// Initial load — full fetch, no filters. Starts delta polling on success.
  Future<void> load() async {
    if (_disposed) return;
    state = state.copyWith(initialState: const UiLoading());
    try {
      final hazards = await _repo.getHazards();
      if (_disposed) return;
      state = state.copyWith(
        hazards: hazards,
        initialState: hazards.isEmpty
            ? const UiEmpty()
            : UiSuccess(hazards),
        lastUpdated: DateTime.now().toUtc(),
        refreshError: null,
      );
      _polling.start();
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(initialState: UiError(e.toString()));
    }
  }

  /// Manual full refresh (pull/refresh button) — resets the delta cursor.
  Future<void> refresh() async {
    if (_disposed || state.refreshing) return;
    state = state.copyWith(refreshing: true, refreshError: null);
    try {
      final hazards = await _repo.getHazards();
      if (_disposed) return;
      _tickCount = 0;
      state = state.copyWith(
        hazards: hazards,
        initialState: hazards.isEmpty
            ? const UiEmpty()
            : UiSuccess(hazards),
        lastUpdated: DateTime.now().toUtc(),
        refreshing: false,
      );
      _polling.restart();
    } catch (e) {
      if (_disposed) return;
      // Keep last-known view; surface non-blocking error.
      state = state.copyWith(refreshing: false, refreshError: e.toString());
    }
  }

  /// Delta poll tick — incremental fetch via updated_since, merged by id.
  ///
  /// ASUMSI-F resolution: the backend has no tombstones (api §4.1), so
  /// every [fullReconcileEveryTicks] ticks the poll becomes a full silent
  /// reconcile that *replaces* the local list — purging hazards deleted
  /// server-side. Foreground resume triggers a reconcile immediately via
  /// [refresh].
  Future<void> pollDelta() async {
    if (_disposed || state.refreshing || state.lastUpdated == null) return;
    _tickCount++;
    if (_tickCount >= fullReconcileEveryTicks) {
      _tickCount = 0;
      await _applyServerList(silent: true);
      return;
    }
    final since = state.lastUpdated!;
    try {
      final updates = await _repo.getHazards(updatedSince: since);
      if (_disposed || updates.isEmpty) {
        if (!_disposed && updates.isEmpty) {
          state = state.copyWith(lastUpdated: DateTime.now().toUtc());
        }
        return;
      }
      final merged = {for (final h in state.hazards) h.id: h};
      for (final h in updates) {
        merged[h.id] = h;
      }
      final list = merged.values.toList();
      if (_disposed) return;
      state = state.copyWith(
        hazards: list,
        initialState: UiSuccess(list),
        lastUpdated: DateTime.now().toUtc(),
        refreshError: null,
      );
    } catch (_) {
      // Transient poll failure — keep last-known view silently; next tick
      // retries. Matches §11 "fall back to last-known cached view".
    }
  }

  /// Full silent replace from server truth. Used by periodic reconcile and
  /// foreground-resume; keeps last-known view on failure.
  Future<void> _applyServerList({required bool silent}) async {
    try {
      final hazards = await _repo.getHazards();
      if (_disposed) return;
      state = state.copyWith(
        hazards: hazards,
        initialState: hazards.isEmpty ? const UiEmpty() : UiSuccess(hazards),
        lastUpdated: DateTime.now().toUtc(),
        refreshing: false,
        refreshError: silent ? null : state.refreshError,
      );
    } catch (e) {
      if (_disposed || silent) return;
      state = state.copyWith(refreshing: false, refreshError: e.toString());
    }
  }

  /// Pause delta polling (app backgrounded) — saves battery/backend load.
  /// Resuming happens via [refresh], which also reconciles server truth.
  void pausePolling() => _polling.stop();

  @override
  void dispose() {
    _disposed = true;
    _polling.stop();
    super.dispose();
  }
}

/// Feature provider — wires repository, polling interval (GAP-05), and
/// the controller together.
final hazardMapControllerProvider =
    StateNotifierProvider<HazardMapController, HazardMapState>((ref) {
      final repo = ref.watch(hazardRepositoryProvider);
      late final HazardMapController controller;
      final polling = PollingService(
        interval: ref.watch(pollIntervalProvider),
        onTick: () => controller.pollDelta(),
      );
      controller = HazardMapController(repo, polling);
      return controller;
    });
