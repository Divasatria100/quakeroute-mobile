import 'package:flutter/material.dart';
import '../../../core/widgets/qr_scaffold.dart';

class SimulationScreen extends StatelessWidget {
  const SimulationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Simulation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          QREmptyState(
            message:
                '6 controlled scenarios + baseline vs risk-aware comparison will be implemented in feature phase.',
            icon: Icons.science_outlined,
          ),
        ],
      ),
    );
  }
}
