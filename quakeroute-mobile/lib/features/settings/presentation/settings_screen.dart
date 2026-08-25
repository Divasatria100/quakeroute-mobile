import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/qr_tokens.dart';
import '../../../core/utils/constants.dart';

/// Settings / About / Safety Disclaimer re-access —
/// ui-ux-specification.md §8.13.
///
/// Low-emphasis static screen: disclaimer re-access, Simulation entry
/// point, app info. No other interactive elements in MVP scope.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & About')),
      body: ListView(
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        children: [
          const _DisclaimerCard(),
          const SizedBox(height: QRTokens.spaceMd),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.science_outlined,
                color: QRTokens.accentCyan,
              ),
              title: const Text('Emergency Simulation'),
              subtitle: const Text(
                'Evaluator tool — run controlled scenarios and compare '
                'baseline vs risk-aware routes.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/simulation'),
            ),
          ),
          const SizedBox(height: QRTokens.spaceMd),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(QRTokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.appName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: QRTokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: QRTokens.spaceXs),
                  const Text(
                    'MVP prototype — post-earthquake risk-aware navigation.',
                    style: TextStyle(
                      fontSize: 13,
                      color: QRTokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: QRTokens.spaceSm),
                  const Text(
                    'Hazard data is community-sourced and AI-assisted; '
                    'costs and routes are computed by the QuakeRoute backend.',
                    style: TextStyle(fontSize: 12, color: QRTokens.textDisabled),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(QRTokens.spaceLg),
      decoration: BoxDecoration(
        color: QRTokens.bgSurface,
        borderRadius: BorderRadius.circular(QRTokens.radiusMd),
        border: Border.fromBorderSide(QRTokens.elevation0Border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.health_and_safety_outlined,
                size: QRTokens.iconMd,
                color: QRTokens.semanticWarning,
              ),
              const SizedBox(width: QRTokens.spaceSm),
              Text(
                'Safety Notice',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: QRTokens.textPrimary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: QRTokens.spaceSm),
          const Text(
            'QuakeRoute is a decision-support tool, not a safety guarantee.',
            style: TextStyle(color: QRTokens.textSecondary),
          ),
          const SizedBox(height: QRTokens.spaceMd),
          OutlinedButton(
            onPressed: () => context.push('/disclaimer'),
            child: const Text('Read full disclaimer'),
          ),
        ],
      ),
    );
  }
}
