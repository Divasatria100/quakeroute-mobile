import 'package:flutter/material.dart';
import '../../../core/theme/qr_tokens.dart';
import '../../../core/widgets/qr_scaffold.dart';

class DestinationScreen extends StatelessWidget {
  const DestinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Destination')),
      body: const QREmptyState(
        message: 'Destinations will be loaded from GET /api/v1/destinations.',
        icon: Icons.place_outlined,
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(QRTokens.spaceLg),
        child: SafeArea(
          child: Text(
            'Foundation skeleton — no API integration yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: QRTokens.textDisabled),
          ),
        ),
      ),
    );
  }
}
