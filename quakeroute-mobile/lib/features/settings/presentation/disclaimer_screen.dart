import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/app_providers.dart';
import '../../../core/theme/qr_tokens.dart';

/// Safety Disclaimer — ui-ux-specification.md §8.1.
/// Full-screen, no skip option (safety-critical acknowledgment).
/// Single "Continue" action. Content mirrors §8.13 re-access copy.
class DisclaimerScreen extends ConsumerWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: QRTokens.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(QRTokens.space2xl),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: QRTokens.bgSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: QRTokens.semanticWarning),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  size: 40,
                  color: QRTokens.semanticWarning,
                ),
              ),
              const SizedBox(height: QRTokens.space2xl),
              const Text(
                'Safety Disclaimer',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: QRTokens.textPrimary,
                ),
              ),
              const SizedBox(height: QRTokens.spaceLg),
              const _DisclaimerBody(),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(disclaimerAcceptedProvider.notifier).state = true;
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QRTokens.accentCyan,
                    foregroundColor: QRTokens.textOnAccent,
                    padding: const EdgeInsets.symmetric(
                      vertical: QRTokens.spaceLg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(QRTokens.radiusMd),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared disclaimer copy — identical text used by Settings re-access
/// (ui-ux §8.13 "disclaimer text (same as 8.1)").
class _DisclaimerBody extends StatelessWidget {
  const _DisclaimerBody();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(QRTokens.spaceLg),
      decoration: BoxDecoration(
        color: QRTokens.bgSurface,
        borderRadius: BorderRadius.circular(QRTokens.radiusLg),
        border: Border.fromBorderSide(QRTokens.elevation0Border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QuakeRoute is a decision-support tool, not a safety guarantee.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: QRTokens.textPrimary,
            ),
          ),
          SizedBox(height: QRTokens.spaceSm),
          Text(
            'Suggested routes are not guaranteed safe. Hazard information '
            'comes from community reports and AI analysis and may be '
            'incomplete or wrong. Always follow instructions from official '
            'responders when they are available.',
            style: TextStyle(color: QRTokens.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}
