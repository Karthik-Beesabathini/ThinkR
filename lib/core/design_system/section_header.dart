import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

/// Uppercase section label with optional trailing widget.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppDimens.pagePadding,
      AppDimens.space6,
      AppDimens.pagePadding,
      AppDimens.space3,
    ),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                    color: colors.textTertiary,
                    letterSpacing: 1.6,
                  ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Thin animated progress track used on cards and the Progress screen.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    super.key,
    required this.value,
    this.color,
    this.height = 4,
  });

  /// 0..1
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: colors.surfaceAlt),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                color: color ?? colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Small rounded chip for quiet metadata ("2P", "SOON", "NEW BEST").
class QuietChip extends StatelessWidget {
  const QuietChip({
    super.key,
    required this.label,
    this.color,
    this.borderColor,
    this.background,
  });

  final String label;
  final Color? color;
  final Color? borderColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background ?? colors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 0.8)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
          color: color ?? colors.textSecondary,
        ),
      ),
    );
  }
}
