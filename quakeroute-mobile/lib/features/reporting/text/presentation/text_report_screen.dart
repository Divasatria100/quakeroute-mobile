import 'package:flutter/material.dart';
import '../../../../core/widgets/qr_scaffold.dart';

class TextReportScreen extends StatelessWidget {
  const TextReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text Report')),
      body: const QREmptyState(
        message:
            'Free-text hazard description + AI extraction review will be implemented in feature phase.',
        icon: Icons.text_fields,
      ),
    );
  }
}
