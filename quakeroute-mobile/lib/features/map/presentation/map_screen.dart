import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/location/location_service.dart';
import '../../../core/models/destination.dart';
import '../../../core/models/hazard.dart' hide LatLng;
import '../../../core/state/app_providers.dart';
import '../../../core/state/ui_state.dart';
import '../../../core/theme/qr_tokens.dart';
import '../../../core/widgets/qr_map_canvas.dart';
import '../../../core/widgets/qr_scaffold.dart';
import '../../routing/controller/routing_controller.dart';
import '../controller/hazard_map_controller.dart';
import '../controller/road_segment_controller.dart';
import 'widgets/destination_pin.dart';
import 'widgets/hazard_detail_sheet.dart';
import 'widgets/hazard_pin.dart';

/// Home — Dynamic Safety Map (PRD §9.1, SRS FR-001–FR-004, ui-ux §8.2).
/// Hazard pins colored by the §10.1 semantic table, live HUD count chip,
/// dynamic bottom sheet, manual refresh + delta polling (GAP-05).
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final LocationService _location = const LocationService();
  final MapController _mapController = MapController();
  late final AppLifecycleListener _lifecycle;
  bool _wasHidden = false;
  List<Destination> _destinations = [];
  Timer? _bboxDebounce;
  String? _lastBbox;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hazardMapControllerProvider.notifier).load();
      ref.read(roadSegmentControllerProvider.notifier).load();
      _loadDestinations();
      _centerOnUser();
    });
    // ASUMSI-F: pause delta polling while backgrounded; on return to the
    // foreground do a full reconcile so deletions/changes are reflected
    // the moment the user looks at the map.
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (!mounted) return;
        _wasHidden = true;
        ref.read(hazardMapControllerProvider.notifier).pausePolling();
      },
      onShow: () {
        if (!mounted || !_wasHidden) return;
        _wasHidden = false;
        ref.read(hazardMapControllerProvider.notifier).refresh();
      },
    );
  }

  @override
  void dispose() {
    _bboxDebounce?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  String? _bboxFromCamera(MapCamera camera) {
    try {
      final bounds = camera.visibleBounds;
      final sw = bounds.southWest;
      final ne = bounds.northEast;
      // Guard against world-wrap or zero-area bounds
      if (sw.longitude == ne.longitude || sw.latitude == ne.latitude) return null;
      return '${sw.longitude},${sw.latitude},${ne.longitude},${ne.latitude}';
    } catch (_) {
      return null;
    }
  }

  void _onPositionChanged(MapCamera camera, bool _) {
    _bboxDebounce?.cancel();
    _bboxDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      final bbox = _bboxFromCamera(camera);
      if (bbox == _lastBbox) return;
      _lastBbox = bbox;
      if (bbox == null) return;
      ref.read(hazardMapControllerProvider.notifier).setBbox(bbox);
      ref.read(roadSegmentControllerProvider.notifier).setBbox(bbox);
    });
  }

  Future<void> _loadDestinations() async {
    try {
      final list = await ref.read(destinationRepositoryProvider).getDestinations();
      if (!mounted) return;
      setState(() => _destinations = list);
    } catch (_) {
      // silent — map still usable without destinations
    }
  }

  /// FR-001: display user location. The HUD crosshair (§8.2 marker style)
  /// represents the user; centering the camera brings it into view.
  Future<void> _centerOnUser() async {
    final loc = await _location.getCurrentLocationOrNull();
    if (!mounted || loc == null) return;
    _mapController.move(LatLng(loc.lat, loc.lng), 14);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hazardMapControllerProvider);
    final roadState = ref.watch(roadSegmentControllerProvider);
    final routingState = ref.watch(routingControllerProvider);
    final route = routingState.routeState.asSuccess?.data;
    final polylines = <Polyline<Object>>[];
    // Road segments base layer — condition-driven styling
    for (final seg in roadState.segments) {
      final pts = seg.geometry.coordinates;
      if (pts.length < 2) continue;
  
      polylines.add(
        Polyline(
          points: pts.map((c) => LatLng(c.lat, c.lng)).toList(),
          color: colorForCondition(seg.condition),
          strokeWidth: strokeForCondition(seg.condition),
        ),
      );
    }
    // Active route on top — distinct thick blue
    final coords = route?.geometry?.coordinates;
    if (coords != null && coords.length >= 2) {
      polylines.add(
        Polyline(
          points: coords.map((c) => LatLng(c.lat, c.lng)).toList(),
          color: QRTokens.semanticInfo,
          strokeWidth: 5,
        ),
      );
    }
    final allMarkers = <Marker>[
      ...state.hazards.map(_pinFor),
      ..._destinations.map(_destinationPin),
    ];

    return Scaffold(
      body: Stack(
        children: [
          QRMapCanvas(markers: allMarkers, polylines: polylines, mapController: _mapController, onPositionChanged: _onPositionChanged),
          _buildTopHud(state),
          if (state.initialState is UiLoading<List<Hazard>>)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (state.initialState is UiError<List<Hazard>>)
            Positioned.fill(
              child: Container(
                color: QRTokens.bgOverlay,
                child: QRErrorState(
                  message:
                      "Couldn't load current conditions. Check your "
                      'connection to the QuakeRoute server.',
                  onRetry: () =>
                      ref.read(hazardMapControllerProvider.notifier).load(),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/report'),
        backgroundColor: QRTokens.accentCyan,
        foregroundColor: QRTokens.textOnAccent,
        icon: const Icon(Icons.add_alert_outlined),
        label: const Text('Report Hazard'),
      ),
      bottomSheet: _DynamicBottomSheet(state: state),
    );
  }

  Marker _pinFor(Hazard h) => Marker(
    point: LatLng(h.location.lat, h.location.lng),
    width: 40,
    height: 40,
    child: GestureDetector(
      onTap: () => showHazardDetailSheet(context, h.id),
      child: HazardPin(semantic: pinSemanticFor(h)),
    ),
  );

  Marker _destinationPin(Destination d) => Marker(
    point: LatLng(d.location.lat, d.location.lng),
    width: 36,
    height: 36,
    child: DestinationPin(
      destination: d,
      onTap: () => context.go('/destinations'),
    ),
  );

  Widget _buildTopHud(HazardMapState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        child: Row(
          children: [
            _HudChip(state: state),
            const Spacer(),
            IconButton(
              onPressed: state.refreshing
                  ? null
                  : () => ref.read(hazardMapControllerProvider.notifier).refresh(),
              icon: state.refreshing
                  ? const SizedBox(
                      width: QRTokens.iconMd,
                      height: QRTokens.iconMd,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              style: IconButton.styleFrom(backgroundColor: QRTokens.bgSurface),
            ),
            const SizedBox(width: QRTokens.spaceSm),
            IconButton(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings_outlined),
              style: IconButton.styleFrom(backgroundColor: QRTokens.bgSurface),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating status chip — "N active hazards nearby" pattern (ui-ux §5.1).
class _HudChip extends StatelessWidget {
  const _HudChip({required this.state});

  final HazardMapState state;

  @override
  Widget build(BuildContext context) {
    final loading = state.initialState is UiLoading<List<Hazard>>;
    final error = state.initialState is UiError<List<Hazard>>;
    final label = loading
        ? 'Scanning hazards…'
        : error
        ? 'Conditions unavailable'
        : '${state.hazards.length} active '
              '${state.hazards.length == 1 ? 'hazard' : 'hazards'} nearby';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: QRTokens.spaceMd,
        vertical: QRTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: QRTokens.bgSurface,
        borderRadius: BorderRadius.circular(QRTokens.radiusFull),
        border: Border.all(color: QRTokens.borderDefault),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            error ? Icons.cloud_off_outlined : Icons.shield_outlined,
            size: QRTokens.iconSm,
            color: error ? QRTokens.semanticDanger : QRTokens.semanticInfo,
          ),
          const SizedBox(width: QRTokens.spaceSm),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: QRTokens.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic bottom sheet — severity breakdown + last-updated + refresh
/// feedback + non-blocking refresh error notice (§8.2 / §11 row 1).
class _DynamicBottomSheet extends ConsumerWidget {
  const _DynamicBottomSheet({required this.state});

  final HazardMapState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(hazardMapControllerProvider.notifier);
    return Container(
      decoration: const BoxDecoration(
        color: QRTokens.bgSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(QRTokens.radiusLg)),
      ),
      padding: const EdgeInsets.all(QRTokens.spaceLg),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dynamic Safety Map',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: QRTokens.textPrimary,
              ),
            ),
            const SizedBox(height: QRTokens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: Text(
                    state.isEmpty && state.initialState is UiSuccess
                        ? 'No active hazards'
                        : 'Current conditions',
                    style: const TextStyle(
                      fontSize: 14,
                      color: QRTokens.textSecondary,
                    ),
                  ),
                ),
                if (state.lastUpdated != null)
                  Text(
                    _formatTime(state.lastUpdated!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: QRTokens.textDisabled,
                    ),
                  ),
                const SizedBox(width: QRTokens.spaceSm),
                OutlinedButton.icon(
                  onPressed: state.refreshing ? null : controller.refresh,
                  icon: const Icon(Icons.refresh, size: QRTokens.iconSm),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            if (state.refreshError != null) ...[
              const SizedBox(height: QRTokens.spaceSm),
              Text(
                'Refresh failed — showing last known data.',
                style: TextStyle(
                  fontSize: 12,
                  color: QRTokens.semanticDanger.withValues(alpha: 0.9),
                ),
              ),
            ],
            const SizedBox(height: QRTokens.spaceMd),
            if (state.hazards.isNotEmpty)
              Wrap(
                spacing: QRTokens.spaceSm,
                runSpacing: QRTokens.spaceSm,
                children: [
                  _SeverityCountChip(
                    semantic: PinSemantic.uncertain,
                    count: state.countWhere(
                      (h) => pinSemanticFor(h) == PinSemantic.uncertain,
                    ),
                  ),
                  _SeverityCountChip(
                    semantic: PinSemantic.critical,
                    count: state.countWhere(
                      (h) => pinSemanticFor(h) == PinSemantic.critical,
                    ),
                  ),
                  _SeverityCountChip(
                    semantic: PinSemantic.danger,
                    count: state.countWhere(
                      (h) => pinSemanticFor(h) == PinSemantic.danger,
                    ),
                  ),
                  _SeverityCountChip(
                    semantic: PinSemantic.warning,
                    count: state.countWhere(
                      (h) => pinSemanticFor(h) == PinSemantic.warning,
                    ),
                  ),
                  _SeverityCountChip(
                    semantic: PinSemantic.info,
                    count: state.countWhere(
                      (h) => pinSemanticFor(h) == PinSemantic.info,
                    ),
                  ),
                ],
              )
            else
              Text(
                state.initialState is UiLoading<List<Hazard>>
                    ? 'Loading hazard data…'
                    : 'The map has no hazard pins right now. This is normal '
                        'when no hazards have been reported yet.',
                style: const TextStyle(fontSize: 13, color: QRTokens.textSecondary),
              ),
            const SizedBox(height: QRTokens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/destinations'),
                    child: const Text('Select Destination'),
                  ),
                ),
                const SizedBox(width: QRTokens.spaceMd),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.go('/route'),
                    child: const Text('View Route'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime utc) {
    final local = utc.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

/// Severity summary chip — icon + count, never color alone (§12.2 rule).
class _SeverityCountChip extends StatelessWidget {
  const _SeverityCountChip({required this.semantic, required this.count});

  final PinSemantic semantic;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: QRTokens.spaceSm,
        vertical: QRTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: semantic.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(QRTokens.radiusFull),
        border: Border.all(color: semantic.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(semantic.icon, size: QRTokens.iconSm, color: semantic.color),
          const SizedBox(width: QRTokens.spaceXs),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: semantic.color,
            ),
          ),
        ],
      ),
    );
  }
}
