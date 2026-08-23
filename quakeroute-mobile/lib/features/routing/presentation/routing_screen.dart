import 'package:flutter/material.dart';
import '../../../core/widgets/qr_scaffold.dart';

class RoutingScreen extends StatelessWidget {
  const RoutingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Route')),
      body: const QREmptyState(
        message:
            'Route display, recalculation banner, and risk breakdown will be implemented in feature phase.',
        icon: Icons.route_outlined,
      ),
    );
  }
}
