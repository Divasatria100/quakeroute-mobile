import 'package:flutter/material.dart';
import '../theme/qr_tokens.dart';

/// Horizontal bar + mono % + status word — §4.2
class QRConfidenceMeter extends StatelessWidget {
  const QRConfidenceMeter({
    required this.confidencePercent,
    required this.status,
    super.key,
  });

  final double confidencePercent;
  final String status;

  @override
  Widget build(BuildContext context) {
    final pct = confidencePercent.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              status,
              style: const TextStyle(
                fontSize: 12,
                color: QRTokens.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: QRTokens.spaceXs),
        LinearProgressIndicator(
          value: pct / 100,
          backgroundColor: QRTokens.borderDefault,
          valueColor: const AlwaysStoppedAnimation<Color>(QRTokens.accentCyan),
        ),
      ],
    );
  }
}
