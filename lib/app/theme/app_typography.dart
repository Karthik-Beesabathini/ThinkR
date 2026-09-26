import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A single typeface family (the platform default) with a strict,
/// restrained hierarchy. Uppercase micro-labels carry the "editorial"
/// premium feel; everything else stays quiet.
TextTheme buildAppTextTheme(AppColors colors) {
  final ink = colors.textPrimary;
  final muted = colors.textSecondary;

  return TextTheme(
    // Game titles, milestone numbers.
    displaySmall: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.4,
      color: ink,
    ),
    // Section / screen titles.
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: -0.2,
      color: ink,
    ),
    // Card titles.
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.25,
      color: ink,
    ),
    // Body copy, instructions.
    bodyMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.45,
      color: ink,
    ),
    // Secondary copy.
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.4,
      color: muted,
    ),
    // Button labels.
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: ink,
    ),
    // Uppercase micro labels (sections, level tags, stats).
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
      color: ink,
    ),
    // Uppercase micro labels, muted variant.
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: muted,
    ),
  );
}
