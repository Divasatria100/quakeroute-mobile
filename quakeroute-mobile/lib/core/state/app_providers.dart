import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/destination/data/destination_repository.dart';
import '../../features/map/data/hazard_repository.dart';
import '../../features/map/data/road_segment_repository.dart';
import '../../features/reporting/data/hazard_report_repository.dart';
import '../../features/routing/data/route_repository.dart';
import '../../features/simulation/data/simulation_repository.dart';
import '../network/api_client.dart';
import '../utils/env_config.dart';
import 'active_route_info.dart';

/// Global Riverpod providers — architecture-document.md §5 core/state.

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// ── Repository providers (Phase 1 Foundation) ──

final hazardRepositoryProvider = Provider<HazardRepository>(
  (ref) => HazardRepository(ref.watch(apiClientProvider)),
);

final destinationRepositoryProvider = Provider<DestinationRepository>(
  (ref) => DestinationRepository(ref.watch(apiClientProvider)),
);

final routeRepositoryProvider = Provider<RouteRepository>(
  (ref) => RouteRepository(ref.watch(apiClientProvider)),
);

final hazardReportRepositoryProvider = Provider<HazardReportRepository>(
  (ref) => HazardReportRepository(ref.watch(apiClientProvider)),
);

final simulationRepositoryProvider = Provider<SimulationRepository>(
  (ref) => SimulationRepository(ref.watch(apiClientProvider)),
);

final roadSegmentRepositoryProvider = Provider<RoadSegmentRepository>(
  (ref) => RoadSegmentRepository(ref.watch(apiClientProvider)),
);

// ── App-level state ──

/// Active route reference held in memory; used by the FR-007
/// "replace current route" confirmation on destination selection.
final activeRouteInfoProvider = StateProvider<ActiveRouteInfo?>(
  (_) => null,
);

/// Connectivity placeholder — to be wired to connectivity_plus if needed.
final connectivityProvider = StateProvider<bool>((ref) => true);

/// Safety disclaimer acceptance — in-memory only, resets every launch
/// (ui-ux §8.1 "shown once"; confirmed Phase 1 decision).
final disclaimerAcceptedProvider = StateProvider<bool>((_) => false);

/// Configurable polling interval for all periodic refresh loops
/// (GAP-05: default 20s via POLL_INTERVAL_SECONDS).
final pollIntervalProvider = Provider<Duration>((ref) => EnvConfig.pollInterval());
