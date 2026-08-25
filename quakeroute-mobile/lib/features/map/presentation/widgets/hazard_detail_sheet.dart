import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/hazard.dart';
import '../../../../core/state/app_providers.dart';
import '../../../../core/theme/qr_tokens.dart';
import '../../../../core/widgets/qr_scaffold.dart';
import 'hazard_pin.dart';

Future<void> showHazardDetailSheet(BuildContext context, String hazardId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: QRTokens.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(QRTokens.radiusLg)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => _HazardDetailContent(
        hazardId: hazardId,
        scrollController: scrollController,
      ),
    ),
  );
}

class _HazardDetailContent extends ConsumerStatefulWidget {
  const _HazardDetailContent({required this.hazardId, required this.scrollController});
  final String hazardId;
  final ScrollController scrollController;

  @override
  ConsumerState<_HazardDetailContent> createState() => _HazardDetailContentState();
}

class _HazardDetailContentState extends ConsumerState<_HazardDetailContent> {
  late Future<Hazard> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(hazardRepositoryProvider).getHazard(widget.hazardId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Hazard>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(QRTokens.spaceLg),
            child: QRLoadingRow(message: 'Loading hazard detail…'),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(QRTokens.spaceLg),
            child: QRErrorState(
              message: 'Could not load hazard detail.',
              onRetry: () => setState(() => _future = ref.read(hazardRepositoryProvider).getHazard(widget.hazardId)),
            ),
          );
        }
        final h = snap.data!;
        final semantic = pinSemanticFor(h);
        final isUncertain = h.status == HazardStatus.uncertainConflicting || h.status == HazardStatus.reported;
        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(QRTokens.spaceLg),
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: QRTokens.borderDefault, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: QRTokens.spaceMd),
            Row(
              children: [
                Icon(semantic.icon, color: semantic.color, size: QRTokens.iconLg),
                const SizedBox(width: QRTokens.spaceSm),
                Expanded(child: Text(h.type.apiValue, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: QRTokens.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: QRTokens.spaceSm, vertical: 2),
                  decoration: BoxDecoration(color: semantic.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(QRTokens.radiusFull)),
                  child: Text(h.status.apiValue, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: semantic.color)),
                ),
              ],
            ),
            const SizedBox(height: QRTokens.spaceMd),
            Wrap(
              spacing: QRTokens.spaceSm,
              runSpacing: QRTokens.spaceSm,
              children: [
                _Badge(label: h.severity.apiValue, color: semantic.color, icon: semantic.icon),
                _Badge(label: h.roadImpact.apiValue, color: QRTokens.textSecondary, icon: Icons.route_outlined),
                _Badge(label: '${(h.confidence * 100).toStringAsFixed(0)}%', color: QRTokens.accentTeal, icon: Icons.analytics_outlined),
              ],
            ),
            if (isUncertain) ...[
              const SizedBox(height: QRTokens.spaceMd),
              Container(
                padding: const EdgeInsets.all(QRTokens.spaceMd),
                decoration: BoxDecoration(color: QRTokens.semanticUncertain.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(QRTokens.radiusMd), border: Border.all(color: QRTokens.semanticUncertain.withValues(alpha: 0.2))),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: QRTokens.iconMd, color: QRTokens.semanticUncertain),
                    const SizedBox(width: QRTokens.spaceSm),
                    const Expanded(child: Text('Reports disagree about this road. It\'s not blocked, but treated as riskier until more information comes in.', style: TextStyle(fontSize: 12, color: QRTokens.textSecondary))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: QRTokens.spaceMd),
            _Row(label: 'Source', value: h.source.apiValue),
            _Row(label: 'Timestamp', value: h.timestamp.toLocal().toString().substring(0, 19)),
            _Row(label: 'Location', value: '${h.location.lat.toStringAsFixed(4)}, ${h.location.lng.toStringAsFixed(4)}'),
            if (h.roadSegmentId != null) _Row(label: 'Segment', value: h.roadSegmentId!.substring(0, 8)),
            if (h.conflictingWith.isNotEmpty) _Row(label: 'Conflicting', value: h.conflictingWith.join(', ')),
            if (h.evidence?.text != null) ...[
              const SizedBox(height: QRTokens.spaceMd),
              const Text('Evidence', style: TextStyle(fontWeight: FontWeight.w600, color: QRTokens.textPrimary)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(QRTokens.spaceMd),
                decoration: BoxDecoration(color: QRTokens.bgSurfaceAlt, borderRadius: BorderRadius.circular(QRTokens.radiusMd)),
                child: Text(h.evidence!.text!, style: const TextStyle(fontSize: 13, color: QRTokens.textSecondary)),
              ),
            ],
            if (h.evidence?.photoUrl != null) ...[
              const SizedBox(height: QRTokens.spaceSm),
              Text('Photo: ${h.evidence!.photoUrl}', style: const TextStyle(fontSize: 12, color: QRTokens.accentBlue)),
            ],
            const SizedBox(height: QRTokens.spaceLg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ),
          ],
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: QRTokens.spaceSm, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(QRTokens.radiusFull), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: QRTokens.iconSm, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color))]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 12, color: QRTokens.textDisabled, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: QRTokens.textPrimary))),
      ]),
    );
  }
}
