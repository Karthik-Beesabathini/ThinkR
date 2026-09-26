import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// Builds the two app themes from the shared semantic palette.
///
/// Components keep their own styling (see core/design_system) — this file
/// only wires the base Material chrome so defaults never leak through.
ThemeData buildAppTheme(AppColors colors) {
  final scheme = ColorScheme(
    brightness: colors.brightness,
    primary: colors.primary,
    onPrimary: colors.onPrimary,
    secondary: colors.textSecondary,
    onSecondary: colors.background,
    error: colors.error,
    onError: colors.background,
    surface: colors.background,
    onSurface: colors.textPrimary,
    surfaceContainerHighest: colors.surfaceAlt,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.background,
    extensions: [colors],
    textTheme: buildAppTextTheme(colors),
    splashFactory: InkSparkle.splashFactory,
    highlightColor: colors.textPrimary.withValues(alpha: 0.04),
    splashColor: colors.textPrimary.withValues(alpha: 0.04),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: colors.textPrimary, size: 24),
      titleTextStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.6,
        color: colors.textSecondary,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
      ),
    ),
  );
}

