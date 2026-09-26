import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

/// A Lights tile: a proper bulb that reads as a light at a glance.
///
/// ON  — filled bulb, white on the accent tile, soft glow.
/// OFF — outlined bulb, dim color on the muted tile, no glow.
class LightTile extends StatelessWidget {
  const LightTile({
    super.key,
    required this.lit,
    required this.isHint,
    required this.accent,
    required this.celebrateTint,
    required this.onTap,
  });

  final bool lit;
  final bool isHint;
  final Color accent;
  final Color celebrateTint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: lit ? accent : celebrateTint,
          borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
          border: Border.all(
            color: isHint
                ? accent
                : lit
                    ? accent
                    : colors.border,
            width: isHint ? 2 : 1,
          ),
          // Soft glow while lit — never more than a whisper.
          boxShadow: lit || isHint
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: isHint ? 0.35 : 0.25),
                    blurRadius: isHint ? 10 : 6,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Scale with the tile so the bulb stays recognizable from
              // small phones to tablets.
              final side = constraints.biggest.shortestSide;
              final iconSize = (side * 0.46).clamp(16.0, 40.0);
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.6, end: 1.0)
                        .animate(animation),
                    child: child,
                  ),
                ),
                child: Icon(
                  key: ValueKey(lit ? 'bulb-on' : 'bulb-off'),
                  lit ? Icons.lightbulb_rounded : Icons.lightbulb_outline,
                  size: iconSize,
                  color: lit ? Colors.white : colors.textTertiary,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

