import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/qr_tokens.dart';
import '../../../../core/widgets/qr_confidence_meter.dart';
import '../controller/photo_report_controller.dart';

class PhotoReportScreen extends ConsumerStatefulWidget {
  const PhotoReportScreen({super.key});
  @override
  ConsumerState<PhotoReportScreen> createState() => _PhotoReportScreenState();
}

class _PhotoReportScreenState extends ConsumerState<PhotoReportScreen> {
  final _picker = ImagePicker();

  Future<void> _pick(ImageSource src) async {
    final f = await _picker.pickImage(source: src, imageQuality: 85);
    if (f != null) ref.read(photoReportControllerProvider.notifier).setPhoto(f.path);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(photoReportControllerProvider);
    ref.listen(photoReportControllerProvider, (prev, next) {
      if (next.step == PhotoStep.success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hazard confirmed and added to map')));
        context.go('/');
      }
      if (next.step == PhotoStep.pick && prev?.step == PhotoStep.submitting) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suggestion rejected')));
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Photo Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        child: _body(state),
      ),
    );
  }

  Widget _body(PhotoReportState s) {
    if (s.step == PhotoStep.pick) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (s.error != null) Text(s.error!, style: const TextStyle(color: QRTokens.semanticDanger)),
        const SizedBox(height: QRTokens.spaceMd),
        FilledButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera), label: const Text('Take Photo')),
        const SizedBox(height: QRTokens.spaceMd),
        OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('Choose from Gallery')),
      ]);
    }
    if (s.step == PhotoStep.preview) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (s.error != null) Text(s.error!, style: const TextStyle(color: QRTokens.semanticDanger)),
        Expanded(child: s.photoPath != null ? Image.file(File(s.photoPath!), fit: BoxFit.contain) : const SizedBox()),
        const SizedBox(height: QRTokens.spaceMd),
        Row(children: [
          OutlinedButton(onPressed: () => ref.read(photoReportControllerProvider.notifier).clearPhoto(), child: const Text('Retake')),
          const SizedBox(width: QRTokens.spaceMd),
          Expanded(child: FilledButton(onPressed: () => ref.read(photoReportControllerProvider.notifier).upload(), child: const Text('Analyze'))),
        ]),
      ]);
    }
    if (s.step == PhotoStep.uploading) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Analyzing photo…')]));
    }
    if (s.step == PhotoStep.review && s.suggestion != null) {
      final p = s.suggestion!.proposedHazard;
      return ListView(children: [
        if (s.error != null) Text(s.error!, style: const TextStyle(color: QRTokens.semanticDanger)),
        if (s.photoPath != null) Image.file(File(s.photoPath!), height: 180, fit: BoxFit.cover),
        const SizedBox(height: QRTokens.spaceMd),
        Text('Detected: ${p.type.apiValue}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        QRConfidenceMeter(confidencePercent: p.confidence * 100, status: p.severity.apiValue),
        const SizedBox(height: 8),
        Text('Severity: ${p.severity.apiValue} • Impact: ${p.roadImpact.apiValue}'),
        const SizedBox(height: QRTokens.spaceLg),
        FilledButton(onPressed: () => ref.read(photoReportControllerProvider.notifier).confirm(), child: const Text('Confirm')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => _showEdit(p), child: const Text('Edit & Confirm')),
        const SizedBox(height: 8),
        TextButton(onPressed: () => ref.read(photoReportControllerProvider.notifier).reject(), child: const Text('Reject')),
      ]);
    }
    if (s.step == PhotoStep.submitting) {
      return const Center(child: CircularProgressIndicator());
    }
    return const Center(child: Text('Done'));
  }

  void _showEdit(dynamic p) {
    // Simple edit: choose type via dialog
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit type'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final t in ['DebrisRubble', 'RoadBlockage', 'Fire', 'Flood', 'ElectricalHazard', 'VisibleBuildingDamage'])
            ListTile(title: Text(t), onTap: () { Navigator.pop(ctx); ref.read(photoReportControllerProvider.notifier).confirm(edits: {'type': t}); }),
        ]),
      ),
    );
  }
}
