// lib/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Your login gradient colors
  static const Color g1 = Color(0xFF0F2027);
  static const Color g2 = Color(0xFF203A43);
  static const Color g3 = Color(0xFF2C5364);

  // Brand / accents derived from gradient
  static const Color primary = g3;           // Buttons, highlights
  static const Color primaryContainer = Color(0xFF1E3946);
  static const Color onPrimary = Colors.white;

  static const Color surface = Color(0xFF0F171B); // Deep surface for cards on dark
  static const Color onSurface = Colors.white;
  static const Color surfaceVariant = Color(0x1AFFFFFF); // white 10% for borders/lines

  static const Color success = Color(0xFF3DDC84);
  static const Color warning = Color(0xFFFFB74D);
  static const Color error = Color(0xFFE57373);

  static const List<Color> gradient = [g1, g2, g3];
}
