import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'qr_tokens.dart';

/// Typography tokens — ui-ux-specification.md §3.3.
/// UI text uses neo-grotesk sans; data values use mono.
abstract final class QRTypography {
  static TextStyle get _uiBase => GoogleFonts.inter();
  static TextStyle get _monoBase => GoogleFonts.jetBrainsMono();

  static TextStyle get display => _uiBase.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    color: QRTokens.textPrimary,
  );

  static TextStyle get h1 => _uiBase.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 28 / 22,
    color: QRTokens.textPrimary,
  );

  static TextStyle get h2 => _uiBase.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    color: QRTokens.textPrimary,
  );

  static TextStyle get h3 => _uiBase.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 22 / 16,
    color: QRTokens.textPrimary,
  );

  static TextStyle get body => _uiBase.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 22 / 15,
    color: QRTokens.textPrimary,
  );

  static TextStyle get bodyStrong => _uiBase.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 22 / 15,
    color: QRTokens.textPrimary,
  );

  static TextStyle get caption => _uiBase.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    color: QRTokens.textSecondary,
  );

  static TextStyle get label => _uiBase.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 16 / 12,
    letterSpacing: 0.4,
    color: QRTokens.textSecondary,
  );

  static TextStyle get dataMono => _monoBase.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 20 / 14,
    color: QRTokens.textPrimary,
  );

  static TextStyle get dataMonoLarge => _monoBase.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 26 / 20,
    color: QRTokens.textPrimary,
  );
}
