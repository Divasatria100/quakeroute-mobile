import 'package:flutter/material.dart';
import '../theme/qr_tokens.dart';

class QREmptyState extends StatelessWidget {
  const QREmptyState({required this.message, super.key, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 48,
              color: QRTokens.textDisabled,
            ),
            const SizedBox(height: QRTokens.spaceMd),
            Text(
              message,
              style: const TextStyle(color: QRTokens.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class QRErrorState extends StatelessWidget {
  const QRErrorState({required this.message, super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: QRTokens.semanticDanger,
            ),
            const SizedBox(height: QRTokens.spaceMd),
            Text(
              message,
              style: const TextStyle(color: QRTokens.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: QRTokens.spaceMd),
              OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

class QRLoadingRow extends StatelessWidget {
  const QRLoadingRow({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: QRTokens.accentCyan),
          if (message != null) ...[
            const SizedBox(height: QRTokens.spaceMd),
            Text(
              message!,
              style: const TextStyle(color: QRTokens.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
