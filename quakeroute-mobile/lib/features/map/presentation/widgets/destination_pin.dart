import 'package:flutter/material.dart';

import '../../../../core/models/destination.dart';
import '../../../../core/theme/qr_tokens.dart';

class DestinationPin extends StatelessWidget {
  const DestinationPin({required this.destination, super.key, this.onTap});

  final Destination destination;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isMedical = destination.type == DestinationType.medicalFacility;
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: 'Destination pin, ${destination.name}, ${destination.type.apiValue}',
        button: true,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: QRTokens.bgSurface,
            shape: BoxShape.circle,
            border: Border.all(color: QRTokens.accentCyan, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Icon(
            isMedical ? Icons.local_hospital : Icons.home_work,
            size: QRTokens.iconMd,
            color: QRTokens.accentCyan,
          ),
        ),
      ),
    );
  }
}
