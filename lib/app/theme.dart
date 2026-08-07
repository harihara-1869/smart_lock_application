import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: ObsidianColors.primary,
      scaffoldBackgroundColor: ObsidianColors.background,
      colorScheme: const ColorScheme.dark(
        primary: ObsidianColors.primary,
        onPrimary: ObsidianColors.onPrimary,
        primaryContainer: ObsidianColors.primaryContainer,
        onPrimaryContainer: ObsidianColors.onPrimaryContainer,
        secondary: ObsidianColors.secondary,
        onSecondary: ObsidianColors.onSecondary,
        surface: ObsidianColors.surface,
        onSurface: ObsidianColors.onSurface,
        error: ObsidianColors.error,
        onError: ObsidianColors.onError,
        outline: ObsidianColors.outline,
        outlineVariant: ObsidianColors.outlineVariant,
      ),
      textTheme: AppTypography.getObsidianTextTheme(ObsidianColors.onSurface),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        color: ObsidianColors.level1Card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: CrystalColors.primary,
      scaffoldBackgroundColor: CrystalColors.background,
      colorScheme: const ColorScheme.light(
        primary: CrystalColors.primary,
        onPrimary: CrystalColors.onPrimary,
        primaryContainer: Color(0xFFE0F2FE),
        onPrimaryContainer: CrystalColors.primary,
        secondary: CrystalColors.primary,
        onSecondary: CrystalColors.onPrimary,
        surface: CrystalColors.surface,
        onSurface: CrystalColors.onSurface,
        error: CrystalColors.error,
        onError: CrystalColors.onError,
        outline: CrystalColors.outline,
        outlineVariant: CrystalColors.outlineVariant,
      ),
      textTheme: AppTypography.getCrystalTextTheme(CrystalColors.onSurface),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        color: CrystalColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
