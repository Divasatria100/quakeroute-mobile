import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/qr_tokens.dart';
import '../../../core/widgets/qr_map_canvas.dart';

/// Home — Dynamic Safety Map (PRD §9.1, SRS FR-001–004, ui-ux §8.2).
/// Foundation skeleton: full-bleed map + HUD + bottom sheet placeholder.
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const QRMapCanvas(),
          // Floating top HUD bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(QRTokens.spaceLg),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: QRTokens.spaceMd,
                      vertical: QRTokens.spaceSm,
                    ),
                    decoration: BoxDecoration(
                      color: QRTokens.bgSurface,
                      borderRadius: BorderRadius.circular(QRTokens.radiusFull),
                      border: Border.all(color: QRTokens.borderDefault),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: QRTokens.iconSm,
                          color: QRTokens.semanticInfo,
                        ),
                        SizedBox(width: QRTokens.spaceSm),
                        Text(
                          'QuakeRoute',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: QRTokens.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => context.go('/simulation'),
                    icon: const Icon(Icons.science_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: QRTokens.bgSurface,
                    ),
                  ),
                ],
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
      bottomSheet: Container(
        decoration: const BoxDecoration(
          color: QRTokens.bgSurface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(QRTokens.radiusLg),
          ),
        ),
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: QRTokens.spaceMd),
                decoration: BoxDecoration(
                  color: QRTokens.borderDefault,
                  borderRadius: BorderRadius.circular(QRTokens.radiusFull),
                ),
              ),
              const Text(
                'Dynamic Safety Map',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: QRTokens.textPrimary,
                ),
              ),
              const SizedBox(height: QRTokens.spaceXs),
              const Text(
                'Map, hazards, and route overlays will appear here.',
                style: TextStyle(fontSize: 13, color: QRTokens.textSecondary),
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
      ),
    );
  }
}
