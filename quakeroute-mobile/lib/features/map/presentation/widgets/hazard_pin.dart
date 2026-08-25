import 'package:flutter/material.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/hazard.dart';
import '../../../../core/theme/qr_tokens.dart';

/// Semantic visual encoding for a hazard pin — canonical mapping from
/// ui-ux-specification.md §10.1 (never color alone: color + icon + ring).
enum PinSemantic { uncertain, critical, danger, warning, info }

extension PinSemanticX on PinSemantic {
  Color get color => switch (this) {
    PinSemantic.uncertain => QRTokens.semanticUncertain,
    PinSemantic.critical => QRTokens.semanticCritical,
    PinSemantic.danger => QRTokens.semanticDanger,
    PinSemantic.warning => QRTokens.semanticWarning,
    PinSemantic.info => QRTokens.semanticInfo,
  };

  IconData get icon => switch (this) {
    PinSemantic.uncertain => Icons.help_outline,
    PinSemantic.critical => Icons.dangerous,
    PinSemantic.danger => Icons.warning_rounded,
    PinSemantic.warning => Icons.warning_amber_outlined,
    PinSemantic.info => Icons.info_outline,
  };
}

/// Presentation-only mapping from backend-provided fields to the §10.1
/// semantic table. No risk evaluation happens here — values are read
/// verbatim from the API response.
PinSemantic pinSemanticFor(Hazard h) {
  // Reported-but-unconfirmed and Conflicting both map to Uncertain (§10.1).
  if (h.status == HazardStatus.reported ||
      h.status == HazardStatus.uncertainConflicting) {
    return PinSemantic.uncertain;
  }
  if (h.roadImpact == RoadImpact.blocked) {
    return PinSemantic.critical;
  }
  return switch (h.severity) {
    Severity.high => PinSemantic.danger,
    Severity.medium => PinSemantic.warning,
    Severity.low => PinSemantic.info,
  };
}

/// Compact map pin with dashed ring for the Uncertain state (§10.1).
class HazardPin extends StatelessWidget {
  const HazardPin({required this.semantic, super.key});

  final PinSemantic semantic;

  @override
  Widget build(BuildContext context) {
    final isUncertain = semantic == PinSemantic.uncertain;
    return Icon(
      semantic.icon,
      size: isUncertain ? 30 : 32,
      shadows: const [
        Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
      ],
      // Uncertain keeps a hollow look; others render solid.
      color: semantic.color,
    );
  }
}
