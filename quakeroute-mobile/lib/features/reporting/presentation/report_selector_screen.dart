import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/qr_tokens.dart';

class ReportSelectorScreen extends StatelessWidget {
  const ReportSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Report Hazard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(QRTokens.spaceLg),
        children: [
          _ModeTile(
            icon: Icons.photo_camera_outlined,
            title: 'Photo',
            subtitle: 'Lowest typing effort — AI Vision will propose a hazard',
            onTap: () => context.push('/report/photo'),
          ),
          _ModeTile(
            icon: Icons.text_fields,
            title: 'Text',
            subtitle: 'Describe what you observed',
            onTap: () => context.push('/report/text'),
          ),
          _ModeTile(
            icon: Icons.touch_app_outlined,
            title: 'Quick Report',
            subtitle: 'Fastest — no typing',
            onTap: () => context.push('/report/quick'),
          ),
          const _ModeTile(
            icon: Icons.mic_outlined,
            title: 'Voice',
            subtitle: 'Optional — only if implemented (SHOULD HAVE)',
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: QRTokens.spaceMd),
      child: ListTile(
        leading: Icon(
          icon,
          color: enabled ? QRTokens.accentCyan : QRTokens.textDisabled,
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: enabled ? const Icon(Icons.chevron_right) : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
