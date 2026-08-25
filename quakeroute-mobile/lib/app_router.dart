import 'package:go_router/go_router.dart';

import 'features/destination/presentation/destination_screen.dart';
import 'features/map/presentation/map_screen.dart';
import 'features/reporting/photo/presentation/photo_report_screen.dart';
import 'features/reporting/presentation/report_selector_screen.dart';
import 'features/reporting/quick_tap/presentation/quick_report_screen.dart';
import 'features/reporting/text/presentation/text_report_screen.dart';
import 'features/routing/presentation/routing_screen.dart';
import 'features/settings/presentation/disclaimer_gate.dart';
import 'features/settings/presentation/disclaimer_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/simulation/presentation/simulation_screen.dart';

/// Hub-and-spoke rooted at Home (ui-ux-specification.md §6).
/// Phase 1: adds /settings + /disclaimer; Home gated by the safety
/// disclaimer shown once per launch.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) =>
          const DisclaimerGate(child: MapScreen()),
    ),
    GoRoute(
      path: '/destinations',
      builder: (context, state) => const DestinationScreen(),
    ),
    GoRoute(
      path: '/report',
      builder: (context, state) => const ReportSelectorScreen(),
    ),
    GoRoute(
      path: '/report/photo',
      builder: (context, state) => const PhotoReportScreen(),
    ),
    GoRoute(
      path: '/report/text',
      builder: (context, state) => const TextReportScreen(),
    ),
    GoRoute(
      path: '/report/quick',
      builder: (context, state) => const QuickReportScreen(),
    ),
    GoRoute(path: '/route', builder: (context, state) => const RoutingScreen()),
    GoRoute(
      path: '/simulation',
      builder: (context, state) => const SimulationScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/disclaimer',
      builder: (context, state) => const DisclaimerScreen(),
    ),
  ],
);
