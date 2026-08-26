import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/destination.dart';
import '../../../core/models/hazard.dart' show LatLng;
import '../../../core/network/api_exception.dart';
import '../../../core/state/app_providers.dart';
import '../../../core/theme/qr_tokens.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/qr_async_view.dart';
import '../controller/destination_controller.dart';

/// Destination Selection — SRS FR-005–FR-007, ui-ux §8.3.
/// Cards show name, type, and haversine distance (no ETA — confirmed
/// decision GAP-03/04). Selecting triggers POST /routes and transitions
/// to Route Overview. Re-selecting with an active route asks FR-007
/// confirmation first.
class DestinationScreen extends ConsumerStatefulWidget {
  const DestinationScreen({super.key});

  @override
  ConsumerState<DestinationScreen> createState() => _DestinationScreenState();
}

class _DestinationScreenState extends ConsumerState<DestinationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = ref.read(destinationControllerProvider.notifier);
      controller.load();
      controller.locateUser();
    });
  }

  Future<void> _onSelect(Destination destination) async {
    final active = ref.read(activeRouteInfoProvider);
    if (active != null) {
      final confirmed = await _confirmReplace(active.destinationName);
      if (!mounted || !confirmed) return;
    }
    try {
      await ref
          .read(destinationControllerProvider.notifier)
          .createRoute(destination);
      if (!mounted) return;
      context.push('/route');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(_routeErrorMessage(e));
    } catch (_) {
      if (!mounted) return;
      _showError('Could not generate the route. Please try again.');
    }
  }

  String _routeErrorMessage(ApiException e) {
    // §8.4 "Route unavailable" / §11 row 3 — distinguishable from a
    // system failure ("absence of a route is an acceptable outcome").
    if (e.statusCode == 409) {
      return 'No feasible route found — every path to this destination '
          'is blocked. You can view reported hazards on the map.';
    }
    if (e.statusCode == 404) {
      return 'That destination is no longer available. Please refresh '
          'the list and pick another one.';
    }
    if (e.code == 'NO_LOCATION' || e.message.trim().isNotEmpty) {
      return e.message;
    }
    return 'Could not generate the route. Please try again.';
  }

  Future<bool> _confirmReplace(String oldDestinationName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace current route?'),
        content: Text(
          'Replace current route to $oldDestinationName with a new route?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: QRTokens.accentCyan,
              foregroundColor: QRTokens.textOnAccent,
            ),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: QRTokens.bgOverlay,
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: QRTokens.semanticDanger,
              size: QRTokens.iconMd,
            ),
            const SizedBox(width: QRTokens.spaceSm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(destinationControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Select Destination'),
      ),
      body: QRAsyncView<List<Destination>>(
        state: state.listState,
        onRetry: () =>
            ref.read(destinationControllerProvider.notifier).load(),
        loadingMessage: 'Loading destinations…',
        emptyIcon: Icons.place_outlined,
        contentBuilder: (context, destinations) => ListView.separated(
          padding: const EdgeInsets.all(QRTokens.spaceLg),
          itemCount: destinations.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: QRTokens.spaceMd),
          itemBuilder: (context, i) => _DestinationCard(
            destination: destinations[i],
            distanceLabel: _distanceLabel(destinations[i], state.userLocation),
            submitting: state.submittingDestinationId == destinations[i].id,
            enabled: state.submittingDestinationId == null,
            onTap: () => _onSelect(destinations[i]),
          ),
        ),
      ),
    );
  }

  String _distanceLabel(Destination d, LatLng? user) {
    if (user == null) return 'Distance unavailable';
    final km = haversineDistanceKm(user.lat, user.lng, d.location.lat, d.location.lng);
    return '${formatDistanceKm(km)} away';
  }
}

/// QRDestinationCard — ui-ux §8.3: name, type, distance (ETA excluded per
/// confirmed GAP-03/04 decision).
class _DestinationCard extends StatelessWidget {
  const _DestinationCard({
    required this.destination,
    required this.distanceLabel,
    required this.submitting,
    required this.enabled,
    required this.onTap,
  });

  final Destination destination;
  final String distanceLabel;
  final bool submitting;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          destination.type == DestinationType.medicalFacility
              ? Icons.local_hospital_outlined
              : Icons.home_work_outlined,
          color: QRTokens.accentCyan,
        ),
        title: Text(destination.name),
        subtitle: Text(distanceLabel),
        trailing: submitting
            ? const SizedBox(
                width: QRTokens.iconLg,
                height: QRTokens.iconLg,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        enabled: enabled,
        onTap: submitting ? null : onTap,
      ),
    );
  }
}
