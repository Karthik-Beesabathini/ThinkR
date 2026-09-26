import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

/// Gameplay top bar: back · level label · menu. Deliberately minimal —
/// the board is the screen.
class GameHeader extends StatelessWidget {
  const GameHeader({
    super.key,
    required this.label,
    this.sublabel,
    this.onBack,
    this.onMenu,
  });

  final String label;

  /// Optional second line (e.g. the chapter name) — keeps players aware
  /// of their arc without leaving the board.
  final String? sublabel;
  final VoidCallback? onBack;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: AppDimens.minTouchTarget,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
              tooltip: 'Back',
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                  color: colors.textSecondary,
                ),
              ),
              if (sublabel != null)
                Text(
                  sublabel!.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: colors.textTertiary,
                  ),
                ),
            ],
          ),
          if (onMenu != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onMenu,
                icon: Icon(Icons.more_horiz_rounded, color: colors.textPrimary),
                tooltip: 'Menu',
              ),
            ),
        ],
      ),
    );
  }
}
