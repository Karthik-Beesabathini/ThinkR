import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

/// The three button voices used everywhere in the app.
/// Primary = ink fill. Secondary = outlined surface. Text = quiet action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.textColor,
    this.height = AppDimens.buttonHeight,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? textColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color ?? colors.primary,
        foregroundColor: textColor ?? colors.onPrimary,
        disabledBackgroundColor:
            (color ?? colors.primary).withValues(alpha: 0.3),
        minimumSize: Size.fromHeight(height),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      child: Text(label),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
    this.height = AppDimens.secondaryButtonHeight,
    this.expanded = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  final double height;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color ?? colors.textPrimary,
        side: BorderSide(color: colors.border, width: 1),
        backgroundColor: colors.surface,
        minimumSize: Size(expanded ? double.infinity : 0, height),
        padding: const EdgeInsets.symmetric(horizontal: AppDimens.space4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
      child: Text(label),
    );
    return button;
  }
}

class TextActionButton extends StatelessWidget {
  const TextActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? context.colors.textSecondary,
        textStyle: Theme.of(context).textTheme.labelLarge,
        minimumSize: const Size(44, AppDimens.secondaryButtonHeight),
      ),
      child: Text(label),
    );
  }
}

/// Quiet circular icon button (header actions, gameplay controls).
class QuietIconButton extends StatelessWidget {
  const QuietIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22, color: color ?? colors.textPrimary),
      constraints: const BoxConstraints(
        minWidth: AppDimens.minTouchTarget,
        minHeight: AppDimens.minTouchTarget,
      ),
    );
  }
}

/// The gameplay hint control: accent-tinted, clearly secondary to the board.
class HintButton extends StatelessWidget {
  const HintButton({super.key, required this.label, this.onPressed, this.accent});

  final String label;
  final VoidCallback? onPressed;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accentColor = accent ?? colors.primary;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(Icons.lightbulb_outline_rounded,
          size: 18, color: accentColor),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: accentColor,
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.35),
          width: 1,
        ),
        backgroundColor: GameAccents.tint(context, accentColor, alpha: 0.08),
        minimumSize: const Size(120, AppDimens.secondaryButtonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}
