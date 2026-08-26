import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/theme/qr_tokens.dart';
import '../../../../core/utils/constants.dart';
import '../controller/quick_report_controller.dart';

class QuickReportScreen extends ConsumerWidget {
  const QuickReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quickReportControllerProvider);
    ref.listen(quickReportControllerProvider, (prev, next) {
      if (next.successId != null && next.successId != prev?.successId) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quick report submitted')));
        context.go('/');
        Future.microtask(() => ref.read(quickReportControllerProvider.notifier).clear());
      }
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!), backgroundColor: QRTokens.semanticDanger));
      }
    });
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Quick Report'),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        mainAxisSpacing: QRTokens.spaceMd,
        crossAxisSpacing: QRTokens.spaceMd,
        children: AppConstants.hazardCategories.map((c) {
          final type = HazardType.fromApi(c);
          final isSubmitting = state.submittingType == type;
          final disabled = state.isSubmitting;
          return Card(
            child: InkWell(
              onTap: disabled ? null : () => ref.read(quickReportControllerProvider.notifier).submit(type),
              borderRadius: BorderRadius.circular(QRTokens.radiusMd),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(QRTokens.spaceMd),
                  child: isSubmitting
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(c, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
