import 'package:flutter/material.dart';
import '../theme/qr_tokens.dart';

/// Atoms — ui-ux-specification.md §4.1
class QRButtonPrimary extends StatelessWidget {
  const QRButtonPrimary({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: QRTokens.accentCyan,
        foregroundColor: QRTokens.textOnAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QRTokens.radiusSm),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: QRTokens.iconMd),
            const SizedBox(width: QRTokens.spaceSm),
          ],
          Text(label),
        ],
      ),
    );
  }
}

class QRButtonSecondary extends StatelessWidget {
  const QRButtonSecondary({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: QRTokens.textPrimary,
        side: const BorderSide(color: QRTokens.borderStrong),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QRTokens.radiusSm),
        ),
      ),
      child: Text(label),
    );
  }
}

class QRButtonGhost extends StatelessWidget {
  const QRButtonGhost({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: QRTokens.textSecondary),
      child: Text(label),
    );
  }
}
