// lib/theme/gradient_background.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  final Alignment begin;
  final Alignment end;

  const GradientBackground({
    super.key,
    required this.child,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}
