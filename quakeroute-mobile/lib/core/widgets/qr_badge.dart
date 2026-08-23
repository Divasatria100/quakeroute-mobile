import 'package:flutter/material.dart';
import '../theme/qr_tokens.dart';

/// QRBadge / QRSeverityBadge / QRStatusBadge — §4.1 / §4.2
/// Encodes semantic status with color + icon + label (never color alone).
class QRBadge extends StatelessWidget {
  const QRBadge({
    required this.label,
    required this.color,
    required this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: QRTokens.spaceSm,
        vertical: QRTokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(QRTokens.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: QRTokens.iconSm, color: color),
          const SizedBox(width: QRTokens.spaceXs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
