import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/route.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/active_route_info.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/state/ui_state.dart';
import '../data/route_repository.dart';

class RoutingScreenState {
  const RoutingScreenState({
    this.routeState = const UiInitial<QuakeRoute>(),
    this.recalculating = false,
    this.lastUpdated,
  });

  final UiState<QuakeRoute> routeState;
  final bool recalculating;
  final DateTime? lastUpdated;

  RoutingScreenState copyWith({
    UiState<QuakeRoute>? routeState,
    bool? recalculating,
    DateTime? lastUpdated,
  }) =>
      RoutingScreenState(
        routeState: routeState ?? this.routeState,
        recalculating: recalculating ?? this.recalculating,
        lastUpdated: lastUpdated ?? this.lastUpdated,
      );
}

class RoutingController extends StateNotifier<RoutingScreenState> {
  RoutingController(this._repo, this._ref) : super(const RoutingScreenState());

  final RouteRepository _repo;
  final Ref _ref;

  Future<void> loadActive() async {
    state = state.copyWith(routeState: const UiLoading(), recalculating: false);
    try {
      final route = await _repo.getActiveRoute();
      if (!mounted) return;
      if (route == null) {
        state = state.copyWith(
          routeState: const UiEmpty(message: 'No active route. Select a destination to generate your lower-risk route.'),
        );
        return;
      }
      _syncActiveInfo(route);
      state = state.copyWith(
        routeState: UiSuccess(route),
        lastUpdated: DateTime.now().toUtc(),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        state = state.copyWith(
          routeState: UiError(
            'No feasible route found — every path to this destination is blocked. You can view reported hazards on the map.',
            code: 'ROUTE_UNAVAILABLE',
          ),
        );
        return;
      }
      state = state.copyWith(routeState: UiError(_friendly(e)));
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(routeState: UiError(_friendly(e)));
    }
  }

  /// Distinct recalculating state — keeps previous route visible while refreshing.
  Future<void> refresh() async {
    final current = state.routeState.asSuccess?.data;
    if (current != null) {
      state = state.copyWith(recalculating: true);
    } else {
      state = state.copyWith(routeState: const UiLoading(message: 'Checking for route updates…'), recalculating: true);
    }
    try {
      final route = await _repo.getActiveRoute();
      if (!mounted) return;
      if (route == null) {
        state = state.copyWith(
          routeState: const UiEmpty(message: 'No active route. Select a destination to generate your lower-risk route.'),
          recalculating: false,
          lastUpdated: DateTime.now().toUtc(),
        );
        return;
      }
      _syncActiveInfo(route);
      state = state.copyWith(
        routeState: UiSuccess(route, isRefresh: current != null),
        recalculating: false,
        lastUpdated: DateTime.now().toUtc(),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      // Keep last known route visible on transient failure, just stop recalculating
      if (current != null) {
        state = state.copyWith(recalculating: false);
      } else if (e.statusCode == 409) {
        state = state.copyWith(
          routeState: UiError(
            'No feasible route found — every path to this destination is blocked. You can view reported hazards on the map.',
            code: 'ROUTE_UNAVAILABLE',
          ),
          recalculating: false,
        );
      } else {
        state = state.copyWith(routeState: UiError(_friendly(e)), recalculating: false);
      }
    } catch (e) {
      if (!mounted) return;
      if (current != null) {
        state = state.copyWith(recalculating: false);
      } else {
        state = state.copyWith(routeState: UiError(_friendly(e)), recalculating: false);
      }
    }
  }

  void _syncActiveInfo(QuakeRoute route) {
    final prev = _ref.read(activeRouteInfoProvider);
    final name = (prev != null && prev.destinationId == route.destinationId) ? prev.destinationName : route.destinationId;
    _ref.read(activeRouteInfoProvider.notifier).state = ActiveRouteInfo(
      routeId: route.id,
      destinationId: route.destinationId,
      destinationName: name,
    );
  }

  static String _friendly(Object e) {
    if (e is ApiException && e.message.trim().isNotEmpty) return e.message;
    return 'Could not load the route. Check your connection to the QuakeRoute server.';
  }
}

final routingControllerProvider = StateNotifierProvider<RoutingController, RoutingScreenState>((ref) {
  return RoutingController(ref.watch(routeRepositoryProvider), ref);
});
