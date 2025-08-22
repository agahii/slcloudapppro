// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Modern gradient colors
  static const Color g1 = Color(0xFF141E30);
  static const Color g2 = Color(0xFF243B55);
  static const Color g3 = Color(0xFF2A5298);

  // Brand / accents
  static const Color primary = Color(0xFF64FFDA); // Bright teal for CTAs
  static const Color primaryContainer = Color(0xFF005B4F);
  static const Color onPrimary = Colors.black;

  static const Color surface = Color(0xFF1E2746); // Deep surface on dark
  static const Color onSurface = Colors.white;
  static const Color surfaceVariant = Color(0x33FFFFFF); // white 20% for borders/lines

  static const Color success = Color(0xFF3DDC84);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFE57373);

  static const List<Color> gradient = [g1, g2, g3];
}
