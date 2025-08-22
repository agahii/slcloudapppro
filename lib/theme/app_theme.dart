// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  /// Builds the modern dark theme used across the app.
  static ThemeData modern() {
    final base = ThemeData.dark(useMaterial3: true);

    final colorScheme = const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      secondary: AppColors.g2,
      onSecondary: Colors.white,
      error: AppColors.error,
    );

    final baseText = GoogleFonts.interTextTheme(base.textTheme);
    final textTheme = baseText.copyWith(
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16),
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ).apply(
      bodyColor: AppColors.onSurface,
      displayColor: AppColors.onSurface,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent, // painted via gradient
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.onSurface,
        ),
        foregroundColor: AppColors.onSurface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primary),
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIconColor: AppColors.onSurface,
        suffixIconColor: AppColors.onSurface.withOpacity(0.7),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface.withOpacity(0.8),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.15),
        thickness: 1,
        space: 32,
      ),
      chipTheme: base.chipTheme.copyWith(
        color: MaterialStatePropertyAll(Colors.white.withOpacity(0.1)),
        labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.onSurface),
        side: BorderSide(color: Colors.white.withOpacity(0.2)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
