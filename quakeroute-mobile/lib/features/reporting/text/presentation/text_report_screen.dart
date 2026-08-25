import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/qr_tokens.dart';
import '../controller/text_report_controller.dart';

class TextReportScreen extends ConsumerStatefulWidget {
  const TextReportScreen({super.key});
  @override
  ConsumerState<TextReportScreen> createState() => _TextReportScreenState();
}

class _TextReportScreenState extends ConsumerState<TextReportScreen> {
  final _ctrl = TextEditingController();
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(textReportControllerProvider);
    ref.listen(textReportControllerProvider, (prev, next) {
      if (next.success && !(prev?.success ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${next.hazards.length} hazard(s) created')));
        context.go('/');
        ref.read(textReportControllerProvider.notifier).reset();
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Text Report')),
      body: Padding(
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'Describe what you observed, e.g. Road blocked by debris near school', border: OutlineInputBorder()),
            ),
            const SizedBox(height: QRTokens.spaceMd),
            if (state.error != null) Text(state.error!, style: const TextStyle(color: QRTokens.semanticDanger, fontSize: 13)),
            const SizedBox(height: QRTokens.spaceMd),
            FilledButton(
              onPressed: state.submitting ? null : () => ref.read(textReportControllerProvider.notifier).submit(_ctrl.text),
              child: state.submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
