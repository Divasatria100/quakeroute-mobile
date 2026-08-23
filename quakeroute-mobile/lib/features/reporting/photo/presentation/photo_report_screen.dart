import 'package:flutter/material.dart';
import '../../../../core/widgets/qr_scaffold.dart';

class PhotoReportScreen extends StatelessWidget {
  const PhotoReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Report')),
      body: const QREmptyState(
        message:
            'Photo capture via image_picker + AI Vision review will be implemented in feature phase.',
        icon: Icons.photo_camera_outlined,
      ),
    );
  }
}
