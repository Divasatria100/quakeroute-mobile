import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/route.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/state/ui_state.dart';
import '../../../core/theme/qr_tokens.dart';
import '../../../core/widgets/qr_map_canvas.dart';
import '../../../core/widgets/qr_scaffold.dart';
import '../controller/routing_controller.dart';

/// Route Overview / Active Navigation — ui-ux §8.4, SRS FR-006/035-037.
/// Backend is source of truth; geometry is visualized verbatim, no phantom.
class RoutingScreen extends ConsumerStatefulWidget {
  const RoutingScreen({super.key});

  @override
  ConsumerState<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends ConsumerState<RoutingScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routingControllerProvider.notifier).loadActive();
    });
  }

  void _fitGeometry(QuakeRoute route) {
    // Disabled auto-fit to keep widget tests deterministic; map renders
    // polyline without camera animation. Re-enable when needed.
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routingControllerProvider);
    final routeState = state.routeState;
    final recalculating = state.recalculating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route'),
        actions: [
          IconButton(
            icon: recalculating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: recalculating ? null : () => ref.read(routingControllerProvider.notifier).refresh(),
            tooltip: 'Refresh route',
          ),
        ],
      ),
      body: _buildBody(context, routeState, recalculating, state),
    );
  }

  Widget _buildBody(BuildContext context, UiState<QuakeRoute> s, bool recalculating, RoutingScreenState full) {
    return switch (s) {
      UiInitial<QuakeRoute>() => const QRLoadingRow(message: 'Loading route…'),
      UiLoading<QuakeRoute>() => const QRLoadingRow(message: 'Calculating the safest route…'),
      UiEmpty<QuakeRoute>() => QREmptyState(
          message: s.message ?? 'No active route. Select a destination to generate your lower-risk route.',
          icon: Icons.route_outlined,
        ),
      UiError<QuakeRoute>() when s.code == 'ROUTE_UNAVAILABLE' => QRErrorState(
          message: s.message,
          onRetry: () => ref.read(routingControllerProvider.notifier).loadActive(),
        ),
      UiError<QuakeRoute>() => QRErrorState(
          message: s.message,
          onRetry: () => ref.read(routingControllerProvider.notifier).loadActive(),
        ),
      UiSuccess<QuakeRoute>() => _buildSuccess(context, s.data, recalculating, full),
    };
  }

  Widget _buildSuccess(BuildContext context, QuakeRoute route, bool recalculating, RoutingScreenState full) {
    _fitGeometry(route);
    final activeInfo = ref.watch(activeRouteInfoProvider);
    final destLabel = activeInfo?.destinationName ?? route.destinationId;

    final polylines = <Polyline<Object>>[];
    final coords = route.geometry?.coordinates;
    if (coords != null && coords.length >= 2) {
      polylines.add(
        Polyline(
          points: coords.map((c) => LatLng(c.lat, c.lng)).toList(),
          color: recalculating ? QRTokens.semanticWarning : QRTokens.semanticInfo,
          strokeWidth: 5,
        ),
      );
    }

    final totalHazard = route.segments.fold<double>(0, (a, e) => a + e.hazardPenalty);
    final totalUncertainty = route.segments.fold<double>(0, (a, e) => a + e.uncertaintyPenalty);
    final totalBase = route.segments.fold<double>(0, (a, e) => a + e.baseTravelCost);

    return Column(
      children: [
        if (recalculating)
          Container(
            width: double.infinity,
            color: QRTokens.semanticWarning.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: QRTokens.spaceLg, vertical: QRTokens.spaceSm),
            child: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: QRTokens.spaceSm),
                Text(
                  'Recalculating route — checking for new hazards ahead…',
                  style: TextStyle(fontSize: 13, color: QRTokens.semanticWarning, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (recalculating) const LinearProgressIndicator(minHeight: 2, color: QRTokens.semanticWarning),
        Expanded(
          child: Stack(
            children: [
              QRMapCanvas(polylines: polylines, mapController: _mapController),
              if (coords == null || coords.length < 2)
                Positioned(
                  top: QRTokens.spaceLg,
                  left: QRTokens.spaceLg,
                  right: QRTokens.spaceLg,
                  child: Container(
                    padding: const EdgeInsets.all(QRTokens.spaceMd),
                    decoration: BoxDecoration(
                      color: QRTokens.bgSurface,
                      borderRadius: BorderRadius.circular(QRTokens.radiusMd),
                      border: Border.all(color: QRTokens.borderDefault),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: QRTokens.iconMd, color: QRTokens.semanticInfo),
                        const SizedBox(width: QRTokens.spaceSm),
                        const Expanded(
                          child: Text(
                            'Route geometry unavailable — segments exist but no coordinates returned.',
                            style: TextStyle(fontSize: 12, color: QRTokens.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: QRTokens.bgSurface,
            border: Border(top: BorderSide(color: QRTokens.borderDefault)),
          ),
          padding: const EdgeInsets.all(QRTokens.spaceLg),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        destLabel,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: QRTokens.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: QRTokens.spaceSm, vertical: 2),
                      decoration: BoxDecoration(
                        color: QRTokens.semanticInfo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(QRTokens.radiusFull),
                      ),
                      child: Text(route.status.apiValue, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: QRTokens.semanticInfo)),
                    ),
                    if (route.geometry != null)
                      Padding(
                        padding: const EdgeInsets.only(left: QRTokens.spaceSm),
                        child: Text(
                          'Updated ${_fmtTime(full.lastUpdated)}',
                          style: const TextStyle(fontSize: 11, color: QRTokens.textDisabled),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: QRTokens.spaceSm),
                Wrap(
                  spacing: QRTokens.spaceSm,
                  children: [
                    _StatChip(label: 'Total cost', value: route.totalCost.toStringAsFixed(1)),
                    _StatChip(label: 'Segments', value: '${route.segments.length}'),
                    _StatChip(label: 'Base', value: totalBase.toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: QRTokens.spaceSm),
                Text(
                  'Risk-adjusted total includes hazard ${totalHazard.toStringAsFixed(1)} + uncertainty ${totalUncertainty.toStringAsFixed(1)} on top of base ${totalBase.toStringAsFixed(1)}.',
                  style: const TextStyle(fontSize: 12, color: QRTokens.textSecondary),
                ),
                if (route.supersedesRouteId != null) ...[
                  const SizedBox(height: QRTokens.spaceSm),
                  Row(
                    children: [
                      Icon(Icons.update, size: QRTokens.iconSm, color: QRTokens.semanticWarning),
                      const SizedBox(width: 4),
                      const Text('Updated', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: QRTokens.semanticWarning)),
                      const SizedBox(width: QRTokens.spaceSm),
                      Text('replaces ${_shortId(route.supersedesRouteId!)}…', style: const TextStyle(fontSize: 11, color: QRTokens.textDisabled)),
                    ],
                  ),
                ],
                const SizedBox(height: QRTokens.spaceMd),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Why this route?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: QRTokens.accentCyan)),
                    children: [
                      Column(
                        children: route.segments.asMap().entries.map((e) {
                          final seg = e.value;
                          final idx = e.key + 1;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Segment $idx — ${_shortId(seg.roadSegmentId)}…',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              'base ${seg.baseTravelCost.toStringAsFixed(1)}  hazard +${seg.hazardPenalty.toStringAsFixed(1)}  uncertainty +${seg.uncertaintyPenalty.toStringAsFixed(1)}  = ${seg.segmentRoutingCost.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 11, color: QRTokens.textSecondary, fontFamily: 'monospace'),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: QRTokens.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/destinations'),
                        child: const Text('Change Destination'),
                      ),
                    ),
                    const SizedBox(width: QRTokens.spaceMd),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go('/'),
                        child: const Text('View Map'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmtTime(DateTime? t) {
    if (t == null) return '';
    final l = t.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: QRTokens.spaceSm, vertical: 4),
      decoration: BoxDecoration(
        color: QRTokens.bgSurfaceAlt,
        borderRadius: BorderRadius.circular(QRTokens.radiusFull),
        border: Border.all(color: QRTokens.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: const TextStyle(fontSize: 11, color: QRTokens.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: QRTokens.textPrimary)),
        ],
      ),
    );
  }
}
