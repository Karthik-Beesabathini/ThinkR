import 'package:flutter/material.dart';

/// Semantic color tokens for the Thinkr design system.
///
/// Feature and game code must never hardcode colors — always go through
/// [AppColors] (exposed as a [ThemeExtension], see `context.colors`).
///
/// The palette is intentionally restrained: warm neutrals, a single ink
/// "primary" that flips with the theme, and calm functional colors.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.error,
    required this.locked,
    required this.scrim,
  });

  final Brightness brightness;

  /// Page background.
  final Color background;

  /// Cards, sheets, nav bar.
  final Color surface;

  /// Subtle filled areas (disabled tiles, chips, secondary fills).
  final Color surfaceAlt;

  /// Hairlines and outlines.
  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// The app's "ink". Near-black in light mode, near-white in dark mode.
  final Color primary;
  final Color onPrimary;

  final Color success;
  final Color warning;
  final Color error;

  /// Muted color for locked/unavailable states.
  final Color locked;

  final Color scrim;

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    background: Color(0xFFF7F6F3),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF0EFEB),
    border: Color(0xFFE6E4DE),
    textPrimary: Color(0xFF17171B),
    textSecondary: Color(0xFF6C6C74),
    textTertiary: Color(0xFF9A9AA2),
    primary: Color(0xFF17171B),
    onPrimary: Color(0xFFF7F6F3),
    success: Color(0xFF2E7D5B),
    warning: Color(0xFFC08A2D),
    error: Color(0xFFB3402E),
    locked: Color(0xFFB9B7B0),
    scrim: Color(0x99171718),
  );

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    background: Color(0xFF121214),
    surface: Color(0xFF1B1B1F),
    surfaceAlt: Color(0xFF242429),
    border: Color(0xFF2E2E34),
    textPrimary: Color(0xFFF2F1EC),
    textSecondary: Color(0xFF9C9BA3),
    textTertiary: Color(0xFF6C6C74),
    primary: Color(0xFFF2F1EC),
    onPrimary: Color(0xFF17171B),
    success: Color(0xFF63B48B),
    warning: Color(0xFFD9A94C),
    error: Color(0xFFE0705A),
    locked: Color(0xFF4A4A52),
    scrim: Color(0xB30A0A0C),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primary,
    Color? onPrimary,
    Color? success,
    Color? warning,
    Color? error,
    Color? locked,
    Color? scrim,
  }) {
    return AppColors(
      brightness: brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      locked: locked ?? this.locked,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      locked: Color.lerp(locked, other.locked, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// Per-game accent colors. All accents share the same muted saturation
/// family so every game feels related to the whole product.
abstract final class GameAccents {
  static const Color oneLine = Color(0xFF4158C7);
  static const Color shift = Color(0xFFB25B3A);
  static const Color lights = Color(0xFF2E7D74);
  static const Color memory = Color(0xFF6D5AA8);
  static const Color numberPath = Color(0xFF3E7A4E);
  static const Color pattern = Color(0xFF8A5A8E);
  static const Color split = Color(0xFF31699E);

  /// Tint used for completed / highlighted fills derived from an accent.
  static Color tint(BuildContext context, Color accent, {double alpha = 0.12}) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Color.alphaBlend(accent.withValues(alpha: alpha), colors.surface);
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
