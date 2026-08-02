import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme getObsidianTextTheme(Color defaultColor) {
    return _buildTextTheme(defaultColor);
  }

  static TextTheme getCrystalTextTheme(Color defaultColor) {
    return _buildTextTheme(defaultColor);
  }

  static TextTheme _buildTextTheme(Color defaultColor) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        letterSpacing: -0.02,
        color: defaultColor,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28, // headline-lg-mobile from spec
        fontWeight: FontWeight.w700,
        height: 36 / 28,
        color: defaultColor,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        letterSpacing: -0.01,
        color: defaultColor,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: defaultColor,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
        color: defaultColor,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: defaultColor,
      ),
      labelMedium: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.05,
        color: defaultColor,
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.08,
        color: defaultColor,
      ),
    );
  }
}
