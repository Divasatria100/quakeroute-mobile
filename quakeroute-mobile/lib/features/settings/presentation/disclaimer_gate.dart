import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/state/app_providers.dart';

/// Wraps Home so the safety disclaimer is shown once per launch
/// before first map use (ui-ux §8.1; in-memory state per Phase 1 decision).
class DisclaimerGate extends ConsumerStatefulWidget {
  const DisclaimerGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DisclaimerGate> createState() => _DisclaimerGateState();
}

class _DisclaimerGateState extends ConsumerState<DisclaimerGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(disclaimerAcceptedProvider)) {
        context.push('/disclaimer');
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
