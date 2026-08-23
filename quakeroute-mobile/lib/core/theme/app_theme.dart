import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'qr_tokens.dart';

/// App Theme — wires QRTokens into ThemeData.
/// Light theme only for MVP (ui-ux-specification.md §3.1).
ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: QRTokens.bgBase,
    colorScheme: const ColorScheme.light(
      primary: QRTokens.accentCyan,
      secondary: QRTokens.accentTeal,
      tertiary: QRTokens.accentBlue,
      surface: QRTokens.bgSurface,
      onPrimary: QRTokens.textOnAccent,
      onSurface: QRTokens.textPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: base.textTheme.displayLarge?.copyWith(
        color: QRTokens.textPrimary,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        color: QRTokens.textPrimary,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: QRTokens.bgSurface,
      foregroundColor: QRTokens.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    dividerColor: QRTokens.borderDefault,
    cardTheme: CardThemeData(
      color: QRTokens.bgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(QRTokens.radiusMd),
        side: const BorderSide(color: QRTokens.borderDefault),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: QRTokens.accentCyan,
        foregroundColor: QRTokens.textOnAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(QRTokens.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: QRTokens.spaceLg,
          vertical: QRTokens.spaceMd,
        ),
      ),
    ),
  );
}
