import 'package:flutter/material.dart';

/// QuakeRoute Design Tokens — single source of truth.
///
/// Implements ui-ux-specification.md §3 (Color, Typography, Spacing,
/// Radius, Elevation, Motion) and §10 semantic palette.
/// No screen may hardcode raw values; always consume via [QRTokens].
abstract final class QRTokens {
  // ── Color — Light Theme (base UI) §3.1 ──
  static const bgBase = Color(0xFFF6FAFB);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgSurfaceAlt = Color(0xFFEEF3F5);
  static const bgOverlay = Color(0xCC0B1A1F);
  static const borderDefault = Color(0xFFD8E2E5);
  static const borderStrong = Color(0xFFB7C6CA);
  static const textPrimary = Color(0xFF0B1A1F);
  static const textSecondary = Color(0xFF4B5D63);
  static const textDisabled = Color(0xFF9AAAAE);
  static const textOnAccent = Color(0xFFFFFFFF);
  static const accentCyan = Color(0xFF06B6D4);
  static const accentTeal = Color(0xFF0D9488);
  static const accentBlue = Color(0xFF2563EB);
  static const gradientBrand = LinearGradient(
    colors: [accentCyan, accentTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Semantic Status Colors §3.2 / §10.1 ──
  static const semanticSafe = Color(0xFF16A34A);
  static const semanticInfo = Color(0xFF2563EB);
  static const semanticUncertain = Color(0xFFB45309);
  static const semanticWarning = Color(0xFFF59E0B);
  static const semanticDanger = Color(0xFFDC2626);
  static const semanticCritical = Color(0xFF9F1239);

  // ── Spacing (4pt grid) §3.4 ──
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 20;
  static const double space2xl = 24;
  static const double space3xl = 32;
  static const double space4xl = 40;
  static const double space5xl = 48;
  static const double space6xl = 64;

  static const double screenPaddingMobile = spaceLg;
  static const double screenPaddingLarge = space2xl;

  // ── Radius §3.5 ──
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusFull = 999;

  // ── Elevation §3.6 ──
  static const elevation0Border = BorderSide(color: borderDefault, width: 1);
  static const elevation1Shadow = BoxShadow(
    color: Color(0x0F0B1A1F),
    blurRadius: 2,
    offset: Offset(0, 1),
  );
  static const elevation2Shadow = BoxShadow(
    color: Color(0x1A0B1A1F),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  // ── Icon sizes §3.7 ──
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;

  // ── Motion §3.8 ──
  static const Duration motionMicro = Duration(milliseconds: 120);
  static const Duration motionStandard = Duration(milliseconds: 200);
  static const Duration motionTransition = Duration(milliseconds: 320);
  static const Duration motionRecalc = Duration(milliseconds: 480);
  static const Duration motionEscalate = Duration(milliseconds: 600);
}
