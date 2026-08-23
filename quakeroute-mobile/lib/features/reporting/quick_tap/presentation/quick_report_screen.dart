import 'package:flutter/material.dart';
import '../../../../core/theme/qr_tokens.dart';
import '../../../../core/utils/constants.dart';

class QuickReportScreen extends StatelessWidget {
  const QuickReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick Report')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        mainAxisSpacing: QRTokens.spaceMd,
        crossAxisSpacing: QRTokens.spaceMd,
        children: AppConstants.hazardCategories.map((c) {
          return Card(
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(QRTokens.radiusMd),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(QRTokens.spaceMd),
                  child: Text(
                    c,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
