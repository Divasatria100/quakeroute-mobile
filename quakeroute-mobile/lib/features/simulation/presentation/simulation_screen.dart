import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/models/destination.dart';
import '../../../core/models/hazard.dart' show LatLng;
import '../../../core/models/route.dart';
import '../../../core/models/simulation.dart';
import '../../../core/state/ui_state.dart';
import '../../../core/theme/qr_tokens.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/qr_map_canvas.dart';
import '../../map/presentation/widgets/hazard_pin.dart';
import '../controller/simulation_controller.dart';

class SimulationScreen extends ConsumerStatefulWidget {
  const SimulationScreen({super.key});
  @override
  ConsumerState<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends ConsumerState<SimulationScreen> {
  final MapController _mapController = MapController();
  final MapController _selectionMapController = MapController();
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(simulationControllerProvider.notifier).loadScenarios();
      ref.read(simulationControllerProvider.notifier).loadDestinations();
    });
  }

  void _fitSimulationBounds(SimulationState s) {
    if (!_mapReady) return;
    final coords = <ll.LatLng>[];
    final baseGeom = s.baselineRouteDetail?.geometry?.coordinates;
    final riskGeom = s.riskAwareRouteDetail?.geometry?.coordinates;

    if (baseGeom != null) {
      coords.addAll(baseGeom.map((c) => ll.LatLng(c.lat, c.lng)));
    }
    if (riskGeom != null) {
      coords.addAll(riskGeom.map((c) => ll.LatLng(c.lat, c.lng)));
    }

    // Include synthetic network nodes if available
    if (s.run?.network != null) {
      for (final n in s.run!.network!.nodes) {
        coords.add(ll.LatLng(n.location.lat, n.location.lng));
      }
    }

    // Include synthetic destinations
    if (s.run?.syntheticDestinations != null) {
      for (final d in s.run!.syntheticDestinations) {
        coords.add(ll.LatLng(d.location.lat, d.location.lng));
      }
    }

    // Include hazard locations from active run only — never global pool.
    final hazards = s.run?.hazardsCreated ?? const <SimulationHazardSummary>[];
    for (final h in hazards) {
      final p = _hazardLatLng(h);
      if (p != null) coords.add(p);
    }
    if (coords.length < 2) return;
    try {
      final bounds = LatLngBounds.fromPoints(coords);
      // Pad slightly so routes/hazards are not clipped at edge.
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(32)),
      );
    } catch (_) {}
  }

  ll.LatLng? _hazardLatLng(SimulationHazardSummary h) {
    if (h.location != null) {
      return ll.LatLng(h.location!.lat, h.location!.lng);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(simulationControllerProvider);

    // Fit camera whenever a new run completes.
    ref.listen<SimulationState>(simulationControllerProvider, (prev, next) {
      if (prev?.run?.runId != next.run?.runId && next.run != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitSimulationBounds(next));
      }
      // Also when route details arrive (geometry enrichment).
      if (prev?.baselineRouteDetail?.id != next.baselineRouteDetail?.id ||
          prev?.riskAwareRouteDetail?.id != next.riskAwareRouteDetail?.id) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitSimulationBounds(next));
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Emergency Simulation'),
      ),
      body: _body(state),
    );
  }

  Widget _body(SimulationState s) {
    final scenariosState = s.scenarios;
    if (scenariosState is UiInitial || scenariosState is UiLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (scenariosState is UiError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(QRTokens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: QRTokens.semanticDanger),
              const SizedBox(height: QRTokens.spaceMd),
              Text(
                (scenariosState as UiError).message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: QRTokens.textSecondary),
              ),
              const SizedBox(height: QRTokens.spaceMd),
              ElevatedButton(
                onPressed: () =>
                    ref.read(simulationControllerProvider.notifier).loadScenarios(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (scenariosState is UiEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(QRTokens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.science_outlined, size: 48, color: QRTokens.textDisabled),
              const SizedBox(height: QRTokens.spaceMd),
              const Text('No scenarios',
                  style: TextStyle(fontWeight: FontWeight.w600, color: QRTokens.textPrimary)),
              const SizedBox(height: QRTokens.spaceSm),
              const Text('No simulation scenarios are configured on the server.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: QRTokens.textSecondary)),
              const SizedBox(height: QRTokens.spaceMd),
              OutlinedButton(
                onPressed: () =>
                    ref.read(simulationControllerProvider.notifier).loadScenarios(),
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }
    if (scenariosState is UiSuccess<List<SimulationScenario>>) {
      final list = scenariosState.data;
      return ListView(
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        children: [
          _CrosshairSelectionMap(state: s, mapController: _selectionMapController),
          const SizedBox(height: QRTokens.spaceMd),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => ref.read(simulationControllerProvider.notifier).confirmLocation(),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: Text(s.locationConfirmed ? 'Location Confirmed' : 'Use This Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: s.locationConfirmed ? QRTokens.semanticSafe : QRTokens.accentCyan,
                    foregroundColor: QRTokens.textOnAccent,
                  ),
                ),
              ),
              const SizedBox(width: QRTokens.spaceSm),
              OutlinedButton.icon(
                onPressed: () => ref.read(simulationControllerProvider.notifier).refreshSimulation(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          if (s.locationConfirmed) ...[
            const SizedBox(height: 4),
            Text('Seed: ${s.seed} • Radius: ${s.radiusM} m',
                style: const TextStyle(fontSize: 10, color: QRTokens.textDisabled)),
          ],
          const SizedBox(height: QRTokens.spaceLg),
          _DestinationPicker(state: s),
          const SizedBox(height: QRTokens.spaceLg),
          const Text('Scenarios',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: QRTokens.textSecondary)),
          const SizedBox(height: QRTokens.spaceSm),
          ...list.map((sc) => _ScenarioCard(
                scenario: sc,
                selected: s.selectedScenarioId == sc.id,
                running: s.running && s.selectedScenarioId == sc.id,
                onTap: s.running
                    ? null
                    : () => ref
                        .read(simulationControllerProvider.notifier)
                        .runScenario(sc.id),
              )),
          if (s.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(s.error!,
                  style: const TextStyle(color: QRTokens.semanticDanger)),
            ),
          if (s.running && s.run == null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: QRTokens.spaceSm),
                Text(
                  'Running ${s.selectedScenarioId ?? ''}…',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          if (s.run != null) ...[
            const SizedBox(height: 20),
            _SimulationResultSection(state: s, mapController: _mapController, onMapReady: () => _mapReady = true),
          ] else if (s.runHandle != null && s.running) ...[
            const SizedBox(height: 16),
            Text(
                'Running ${s.runHandle!.scenarioId}… (${s.runHandle!.runId.substring(0, 8)})'),
            const LinearProgressIndicator(),
          ],
        ],
      );
    }
    return const SizedBox();
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard(
      {required this.scenario, required this.selected, required this.running, this.onTap});
  final SimulationScenario scenario;
  final bool selected;
  final bool running;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? QRTokens.accentCyan.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QRTokens.radiusMd),
        side: BorderSide(
          color: selected ? QRTokens.accentCyan : QRTokens.borderDefault,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        title: Text(scenario.name,
            style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? QRTokens.accentCyan : QRTokens.textPrimary)),
        subtitle: Text(scenario.id,
            style: const TextStyle(fontSize: 12, color: QRTokens.textSecondary)),
        trailing: running
            ? const SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(
                selected ? Icons.check_circle : Icons.play_arrow,
                color: selected ? QRTokens.accentCyan : QRTokens.textSecondary,
              ),
        onTap: onTap,
      ),
    );
  }
}

class _DestinationPicker extends ConsumerWidget {
  const _DestinationPicker({required this.state});
  final SimulationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destState = state.destinations;
    final origin = state.simulationCenter;

    Widget content;
    if (destState is UiLoading || destState is UiInitial) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 8),
            Text('Loading destinations…', style: TextStyle(fontSize: 13, color: QRTokens.textSecondary)),
          ],
        ),
      );
    } else if (destState is UiError) {
      content = Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: QRTokens.semanticDanger),
          const SizedBox(width: 6),
          Expanded(
              child: Text((destState as UiError).message,
                  style: const TextStyle(fontSize: 12, color: QRTokens.semanticDanger))),
          TextButton(
              onPressed: () => ref.read(simulationControllerProvider.notifier).loadDestinations(),
              child: const Text('Retry')),
        ],
      );
    } else if (destState is UiEmpty) {
      content = const Text('No destinations available',
          style: TextStyle(fontSize: 13, color: QRTokens.textSecondary));
    } else if (destState is UiSuccess<List<Destination>>) {
      final dests = destState.data;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.place_outlined, size: 16, color: QRTokens.accentCyan),
              SizedBox(width: 6),
              Text('Destination',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: QRTokens.textSecondary)),
              SizedBox(width: 6),
              Text('(distance from simulation origin)',
                  style: TextStyle(fontSize: 10, color: QRTokens.textDisabled)),
            ],
          ),
          const SizedBox(height: 8),
          ...dests.map((d) {
            final isSelected = state.selectedDestinationId == d.id;
            final km = haversineDistanceKm(origin.lat, origin.lng, d.location.lat, d.location.lng);
            final label = formatDistanceKm(km);
            return Card(
              color: isSelected ? QRTokens.accentCyan.withValues(alpha: 0.08) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(QRTokens.radiusMd),
                side: BorderSide(color: isSelected ? QRTokens.accentCyan : QRTokens.borderDefault, width: isSelected ? 1.5 : 1),
              ),
              child: ListTile(
                leading: Icon(
                  d.type == DestinationType.shelter ? Icons.home_work_outlined : Icons.local_hospital_outlined,
                  color: isSelected ? QRTokens.accentCyan : QRTokens.textSecondary,
                ),
                title: Text(d.name, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600, color: isSelected ? QRTokens.accentCyan : QRTokens.textPrimary)),
                subtitle: Text(label, style: const TextStyle(fontSize: 12, color: QRTokens.textSecondary)),
                trailing: isSelected ? const Icon(Icons.check_circle, color: QRTokens.accentCyan) : null,
                onTap: () => ref.read(simulationControllerProvider.notifier).selectDestination(d.id),
              ),
            );
          }),
        ],
      );
    } else {
      content = const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(QRTokens.spaceMd),
      decoration: BoxDecoration(
        color: QRTokens.bgSurfaceAlt,
        borderRadius: BorderRadius.circular(QRTokens.radiusMd),
        border: Border.all(color: QRTokens.borderDefault),
      ),
      child: content,
    );
  }
}

class _CrosshairSelectionMap extends ConsumerWidget {
  const _CrosshairSelectionMap({required this.state, required this.mapController});
  final SimulationState state;
  final MapController mapController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = state.simulationCenter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.my_location, size: 16, color: QRTokens.accentCyan),
            SizedBox(width: 6),
            Text('Simulation Center (drag map under crosshair)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: QRTokens.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(QRTokens.radiusMd),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                QRMapCanvas(
                  center: ll.LatLng(center.lat, center.lng),
                  mapController: mapController,
                  onPositionChanged: (camera, hasGesture) {
                    // Map moves, crosshair stays — update center.
                    if (!hasGesture) return;
                    final c = camera.center;
                    ref.read(simulationControllerProvider.notifier).selectCenter(LatLng(c.latitude, c.longitude));
                  },
                ),
                // Fixed crosshair.
                const Center(
                  child: IgnorePointer(
                    child: Icon(Icons.add, size: 32, color: QRTokens.semanticDanger, shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(4), border: Border.all(color: QRTokens.borderDefault)),
                    child: Text('✚ Lat: ${center.lat.toStringAsFixed(6)}, Lng: ${center.lng.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 10, color: QRTokens.textSecondary, fontFamily: 'monospace')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text('Drag map — crosshair stays fixed. Tap Use This Location to lock center.',
            style: TextStyle(fontSize: 10, color: QRTokens.textDisabled)),
      ],
    );
  }
}

class _SimulationResultSection extends StatelessWidget {
  const _SimulationResultSection(
      {required this.state, required this.mapController, required this.onMapReady});
  final SimulationState state;
  final MapController mapController;
  final VoidCallback onMapReady;

  @override
  Widget build(BuildContext context) {
    final run = state.run!;
    final baselineDetail = state.baselineRouteDetail;
    final riskDetail = state.riskAwareRouteDetail;
    final baselineSummary = run.baselineRoute;
    final riskSummary = run.riskAwareRoute;
    final hazards = run.hazardsCreated;

    // Polyline construction — background synthetic network, baseline, risk-aware.
    final polylines = <Polyline<Object>>[];

    // Render background synthetic network grid
    if (run.network != null) {
      for (final seg in run.network!.segments) {
        if (seg.coordinates.length >= 2) {
          polylines.add(
            Polyline(
              points: seg.coordinates.map((c) => ll.LatLng(c.lat, c.lng)).toList(),
              color: QRTokens.borderDefault.withValues(alpha: 0.8),
              strokeWidth: 2.5,
            ),
          );
        }
      }
    }

    // Baseline: neutral / thinner — visible even when overlapping.
    final baseCoords = baselineDetail?.geometry?.coordinates ??
        _coordsFromSummary(baselineSummary);
    if (baseCoords != null && baseCoords.length >= 2) {
      polylines.add(
        Polyline(
          points: baseCoords.map((c) => ll.LatLng(c.lat, c.lng)).toList(),
          color: QRTokens.textSecondary.withValues(alpha: 0.9),
          strokeWidth: 4,
          borderColor: Colors.white.withValues(alpha: 0.9),
          borderStrokeWidth: 1,
        ),
      );
    }

    // Risk-aware: prominent blue on top.
    final riskCoords = riskDetail?.geometry?.coordinates ??
        _coordsFromSummary(riskSummary);
    if (riskCoords != null && riskCoords.length >= 2) {
      polylines.add(
        Polyline(
          points: riskCoords.map((c) => ll.LatLng(c.lat, c.lng)).toList(),
          color: QRTokens.semanticInfo,
          strokeWidth: 5.5,
          borderColor: Colors.white.withValues(alpha: 0.9),
          borderStrokeWidth: 1,
        ),
      );
    }

    // Markers — exclusively from activeSimulationRun.hazards, plus synthetic origin/destinations
    final markers = <Marker>[];

    // Simulation Center Origin Marker
    if (run.origin != null) {
      markers.add(
        Marker(
          point: ll.LatLng(run.origin!.lat, run.origin!.lng),
          width: 32,
          height: 32,
          child: Container(
            decoration: const BoxDecoration(
              color: QRTokens.accentCyan,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
            ),
            child: const Icon(Icons.my_location, size: 18, color: Colors.white),
          ),
        ),
      );
    }

    // Synthetic Destinations Markers
    for (final d in run.syntheticDestinations) {
      markers.add(
        Marker(
          point: ll.LatLng(d.location.lat, d.location.lng),
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: d.type == 'MedicalFacility' ? QRTokens.semanticDanger : QRTokens.semanticSafe,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              d.type == 'MedicalFacility' ? Icons.local_hospital : Icons.home_work,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Hazard markers
    for (final h in hazards) {
      final pos = _hazardPoint(h);
      if (pos == null) continue;
      markers.add(
        Marker(
          point: pos,
          width: 44,
          height: 44,
          child: _SimulationHazardPin(hazard: h),
        ),
      );
    }

    final isNoHazard = hazards.isEmpty;
    final routesEqual = run.routesDiffer == false &&
        baselineSummary != null &&
        riskSummary != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: QRTokens.spaceSm, vertical: 4),
              decoration: BoxDecoration(
                color: QRTokens.semanticInfo.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(QRTokens.radiusFull),
              ),
              child: Text(run.scenarioId,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: QRTokens.semanticInfo)),
            ),
            const SizedBox(width: QRTokens.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: QRTokens.spaceSm, vertical: 4),
              decoration: BoxDecoration(
                color: QRTokens.bgSurfaceAlt,
                borderRadius: BorderRadius.circular(QRTokens.radiusFull),
                border: Border.all(color: QRTokens.borderDefault),
              ),
              child: Text(run.status,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: QRTokens.textSecondary)),
            ),
            const Spacer(),
            if (isNoHazard)
              const Icon(Icons.verified_outlined,
                  size: QRTokens.iconSm, color: QRTokens.semanticSafe),
          ],
        ),
        const SizedBox(height: QRTokens.spaceMd),
        // Map — fixed height panel.
        ClipRRect(
          borderRadius: BorderRadius.circular(QRTokens.radiusMd),
          child: SizedBox(
            height: 260,
            child: QRMapCanvas(
              markers: markers,
              polylines: polylines,
              mapController: mapController,
              onPositionChanged: null,
            ),
          ),
        ),
        // Fire onMapReady once the map has a controller.
        Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onMapReady());
          return const SizedBox.shrink();
        }),
        const SizedBox(height: QRTokens.spaceMd),
        _SimulationLegend(routesEqual: routesEqual, hasHazard: hazards.isNotEmpty),
        const SizedBox(height: QRTokens.spaceMd),
        _SimulationSummary(
          run: run,
          baselineDetail: baselineDetail,
          riskDetail: riskDetail,
          isNoHazard: isNoHazard,
          routesEqual: routesEqual,
        ),
      ],
    );
  }

  List<LatLng>? _coordsFromSummary(SimulationRouteSummary? s) {
    if (s?.geometry == null) return null;
    return s!.geometry!.coordinates;
  }

  ll.LatLng? _hazardPoint(SimulationHazardSummary h) {
    if (h.location != null) {
      return ll.LatLng(h.location!.lat, h.location!.lng);
    }
    return null;
  }
}

class _SimulationHazardPin extends StatelessWidget {
  const _SimulationHazardPin({required this.hazard});
  final SimulationHazardSummary hazard;

  @override
  Widget build(BuildContext context) {
    final semantic = _semantic(hazard);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: semantic.color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: Icon(semantic.icon, size: 18, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: QRTokens.borderDefault),
          ),
          child: Text(
            hazard.roadImpact.toUpperCase(),
            style: TextStyle(
                fontSize: 7, fontWeight: FontWeight.w800, color: semantic.color),
          ),
        ),
      ],
    );
  }

  PinSemantic _semantic(SimulationHazardSummary h) {
    final status = h.status;
    if (status == 'Reported' || status == 'UncertainConflicting') {
      return PinSemantic.uncertain;
    }
    if (h.roadImpact == 'Blocked') return PinSemantic.critical;
    switch (h.severity) {
      case 'High':
        return PinSemantic.danger;
      case 'Medium':
        return PinSemantic.warning;
      case 'Low':
        return PinSemantic.info;
      default:
        return PinSemantic.warning;
    }
  }
}

class _SimulationLegend extends StatelessWidget {
  const _SimulationLegend({required this.routesEqual, required this.hasHazard});
  final bool routesEqual;
  final bool hasHazard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(QRTokens.spaceMd),
      decoration: BoxDecoration(
        color: QRTokens.bgSurfaceAlt,
        borderRadius: BorderRadius.circular(QRTokens.radiusMd),
        border: Border.all(color: QRTokens.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Route Comparison',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: QRTokens.textPrimary)),
          const SizedBox(height: QRTokens.spaceSm),
          Row(
            children: [
              Container(width: 20, height: 4, color: QRTokens.textSecondary.withValues(alpha: 0.9)),
              const SizedBox(width: QRTokens.spaceSm),
              const Text('Baseline',
                  style: TextStyle(fontSize: 12, color: QRTokens.textSecondary)),
              const SizedBox(width: QRTokens.spaceSm),
              const Text('Normal route without hazard impact',
                  style: TextStyle(fontSize: 10, color: QRTokens.textDisabled)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(width: 20, height: 5, color: QRTokens.semanticInfo),
              const SizedBox(width: QRTokens.spaceSm),
              const Text('Risk-aware',
                  style: TextStyle(fontSize: 12, color: QRTokens.textSecondary)),
              const SizedBox(width: QRTokens.spaceSm),
              const Text('Route after hazard/risk assessment',
                  style: TextStyle(fontSize: 10, color: QRTokens.textDisabled)),
            ],
          ),
          if (hasHazard) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                        color: QRTokens.semanticCritical, shape: BoxShape.circle)),
                const SizedBox(width: QRTokens.spaceSm),
                const Text('Simulation Hazard',
                    style:
                        TextStyle(fontSize: 12, color: QRTokens.textSecondary)),
                const SizedBox(width: QRTokens.spaceSm),
                const Text('Detected simulated hazard',
                    style:
                        TextStyle(fontSize: 10, color: QRTokens.textDisabled)),
              ],
            ),
          ],
          if (routesEqual) ...[
            const SizedBox(height: QRTokens.spaceSm),
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: QRTokens.iconSm, color: QRTokens.semanticInfo),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Routes overlap — hazard did not change the optimal path. Risk-aware keeps the normal route.',
                    style: TextStyle(fontSize: 11, color: QRTokens.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SimulationSummary extends StatelessWidget {
  const _SimulationSummary({
    required this.run,
    required this.baselineDetail,
    required this.riskDetail,
    required this.isNoHazard,
    required this.routesEqual,
  });
  final SimulationRun run;
  final QuakeRoute? baselineDetail;
  final QuakeRoute? riskDetail;
  final bool isNoHazard;
  final bool routesEqual;

  @override
  Widget build(BuildContext context) {
    final hazards = run.hazardsCreated;
    final baselineSummary = run.baselineRoute;
    final riskSummary = run.riskAwareRoute;

    String pathLabel(SimulationRouteSummary? s, QuakeRoute? detail) {
      if (detail != null && detail.segments.isNotEmpty) {
        return detail.segments
            .map<String>((e) => _shortSeg(e.roadSegmentId))
            .join(' → ');
      }
      if (s != null && s.segments.isNotEmpty) {
        return s.segments
            .map<String>((e) => _shortSeg(e.roadSegmentId))
            .join(' → ');
      }
      return '—';
    }

    return Container(
      padding: const EdgeInsets.all(QRTokens.spaceMd),
      decoration: BoxDecoration(
        color: QRTokens.bgSurface,
        borderRadius: BorderRadius.circular(QRTokens.radiusMd),
        border: Border.all(color: QRTokens.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Simulation Complete',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: QRTokens.textPrimary)),
          const SizedBox(height: QRTokens.spaceSm),
          _row(label: 'Scenario', value: run.scenarioId),
          const Divider(height: 16),
          if (isNoHazard) ...[
            const Row(
              children: [
                Icon(Icons.verified, size: QRTokens.iconSm, color: QRTokens.semanticSafe),
                SizedBox(width: 6),
                Expanded(
                  child: Text('No hazards detected. Risk-aware routing keeps the normal route.',
                      style: TextStyle(fontSize: 12, color: QRTokens.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: QRTokens.spaceSm),
          ] else ...[
            for (final h in hazards)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded,
                        size: QRTokens.iconSm, color: _hazardColor(h)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${h.type} — ${h.roadImpact}${h.severity != null ? ' (${h.severity})' : ''}${h.roadSegmentId != null ? ' on ${_shortSeg(h.roadSegmentId!)}' : ''}',
                        style: const TextStyle(fontSize: 12, color: QRTokens.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 16),
          ],
          _row(
              label: 'Baseline',
              value:
                  '${pathLabel(baselineSummary, baselineDetail)}  ·  Cost: ${baselineSummary?.totalCost.toStringAsFixed(1) ?? '—'}'),
          const SizedBox(height: 6),
          _row(
              label: 'Risk-aware',
              value:
                  '${pathLabel(riskSummary, riskDetail)}  ·  Cost: ${riskSummary?.totalCost.toStringAsFixed(1) ?? '—'}'),
          const SizedBox(height: QRTokens.spaceSm),
          Row(
            children: [
              Icon(
                  routesEqual || isNoHazard ? Icons.check_circle_outline : Icons.alt_route,
                  size: QRTokens.iconSm,
                  color: routesEqual || isNoHazard
                      ? QRTokens.semanticSafe
                      : QRTokens.semanticInfo),
              const SizedBox(width: 6),
              Text(
                routesEqual || isNoHazard
                    ? 'Route changed: No'
                    : 'Route changed: Yes',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: routesEqual || isNoHazard
                        ? QRTokens.textSecondary
                        : QRTokens.semanticInfo),
              ),
              if (!routesEqual && !isNoHazard) ...[
                const SizedBox(width: QRTokens.spaceSm),
                const Expanded(
                  child: Text(
                    'Risk-aware routing avoided the hazard by selecting an alternative path.',
                    style: TextStyle(fontSize: 11, color: QRTokens.textDisabled),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _row({required String label, required String value}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: QRTokens.textSecondary))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12, color: QRTokens.textPrimary))),
        ],
      );

  String _shortSeg(String id) {
    return id.length > 8 ? '${id.substring(0, 8)}…' : id;
  }

  Color _hazardColor(SimulationHazardSummary h) {
    if (h.roadImpact == 'Blocked') return QRTokens.semanticCritical;
    switch (h.severity) {
      case 'High':
        return QRTokens.semanticDanger;
      case 'Medium':
        return QRTokens.semanticWarning;
      default:
        return QRTokens.semanticInfo;
    }
  }
}
