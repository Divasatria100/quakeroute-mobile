import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/models/destination.dart';
import '../../../core/models/hazard.dart' show LatLng;
import '../../../core/models/route.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/state/active_route_info.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/state/ui_state.dart';
import '../../routing/data/route_repository.dart';
import '../data/destination_repository.dart';

/// Presentation state for Destination Selection (ui-ux §8.3).
class DestinationScreenState {
  const DestinationScreenState({
    this.listState = const UiInitial<List<Destination>>(),
    this.userLocation,
    this.locating = false,
    this.submittingDestinationId,
  });

  final UiState<List<Destination>> listState;

  /// Current device location used for the haversine distance label
  /// (confirmed decision GAP-03). Null when permission denied/unavailable.
  final LatLng? userLocation;
  final bool locating;

  /// Id of the destination whose route is currently being generated —
  /// drives the inline per-card spinner.
  final String? submittingDestinationId;

  DestinationScreenState copyWith({
    UiState<List<Destination>>? listState,
    LatLng? userLocation,
    bool? locating,
    String? Function()? submittingDestinationId,
  }) => DestinationScreenState(
    listState: listState ?? this.listState,
    userLocation: userLocation ?? this.userLocation,
    locating: locating ?? this.locating,
    submittingDestinationId: submittingDestinationId == null
        ? this.submittingDestinationId
        : submittingDestinationId(),
  );
}

/// Controller for FR-005–FR-007: fetch the controlled destination set and
/// trigger initial route generation on selection. Route computation is
/// backend-owned; this class only orchestrates calls and UI state.
class DestinationController extends StateNotifier<DestinationScreenState> {
  DestinationController(this._destinationRepo, this._routeRepo, this._ref)
    : super(const DestinationScreenState());

  final DestinationRepository _destinationRepo;
  final RouteRepository _routeRepo;
  final Ref _ref;

  final LocationService _locationService = const LocationService();

  /// GET /destinations. Empty is NOT a valid state (§8.3) — mapped to a
  /// retryable error instead.
  Future<void> load() async {
    state = state.copyWith(listState: const UiLoading());
    try {
      final destinations = await _destinationRepo.getDestinations();
      if (!mounted) return;
      state = state.copyWith(
        listState: destinations.isEmpty
            ? const UiError(
                'The server returned no destinations. This should not '
                'happen — please retry.',
              )
            : UiSuccess(destinations),
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        listState: UiError(friendlyLoadErrorMessage(e)),
      );
    }
  }

  /// One-shot device location lookup for the distance labels (FR-001 data).
  Future<void> locateUser() async {
    state = state.copyWith(locating: true);
    final loc = await _locationService.getCurrentLocationOrNull();
    if (!mounted) return;
    state = state.copyWith(userLocation: loc, locating: false);
  }

  /// POST /routes for the chosen destination (FR-006). Throws on failure —
  /// the screen surfaces a friendly message. On success the in-memory
  /// active-route reference is updated (used by FR-007 confirmation).
  Future<QuakeRoute> createRoute(Destination destination) async {
    var origin = state.userLocation;
    if (origin == null) {
      await locateUser();
      origin = state.userLocation;
    }
    if (!mounted) throw const ApiException(code: 'CANCELLED', message: 'Cancelled');
    if (origin == null) {
      throw const ApiException(
        code: 'NO_LOCATION',
        message:
            'Your location could not be determined. Enable location access '
            'and try again.',
      );
    }

    state = state.copyWith(
      submittingDestinationId: () => destination.id,
    );
    try {
      final route = await _routeRepo.createRoute(
        destinationId: destination.id,
        origin: origin,
      );
      _ref.read(activeRouteInfoProvider.notifier).state = ActiveRouteInfo(
        routeId: route.id,
        destinationId: destination.id,
        destinationName: destination.name,
      );
      return route;
    } finally {
      if (mounted) {
        state = state.copyWith(submittingDestinationId: () => null);
      }
    }
  }

  /// Plain-language messages for load failures; keeps API-provided text
  /// when the backend supplies one (never raw stack traces, ui-ux §11).
  static String friendlyLoadErrorMessage(Object e) {
    if (e is ApiException && e.message.trim().isNotEmpty) {
      return 'Could not load destinations: ${e.message}';
    }
    return 'Could not load destinations. Check your connection to the '
        'QuakeRoute server.';
  }
}

final destinationControllerProvider =
    StateNotifierProvider<DestinationController, DestinationScreenState>((
      ref,
    ) {
      return DestinationController(
        ref.watch(destinationRepositoryProvider),
        ref.watch(routeRepositoryProvider),
        ref,
      );
    });
