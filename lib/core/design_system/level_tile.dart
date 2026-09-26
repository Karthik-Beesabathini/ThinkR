import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

enum LevelTileStatus { locked, available, current, completed, completedPerfect }

/// One level in the selection grid.
///
/// State is communicated through fill, border, typography and a small
/// symbol — never color alone (accessibility rule).
class LevelTile extends StatelessWidget {
  const LevelTile({
    super.key,
    required this.level,
    required this.status,
    required this.accent,
    required this.onTap,
  });

  final int level;
  final LevelTileStatus status;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = level.toString().padLeft(2, '0');

    final Color background;
    final Color foreground;
    final BorderSide side;
    Widget? badge;

    switch (status) {
      case LevelTileStatus.locked:
        background = colors.surface.withValues(alpha: 0.4);
        foreground = colors.locked;
        side = BorderSide(color: colors.border.withValues(alpha: 0.5), width: 0.8);
      case LevelTileStatus.available:
        background = colors.surface;
        foreground = colors.textPrimary;
        side = BorderSide(color: colors.border, width: 1);
      case LevelTileStatus.current:
        background = colors.primary;
        foreground = colors.onPrimary;
        side = BorderSide(color: colors.primary, width: 1);
      case LevelTileStatus.completed:
        background = GameAccents.tint(context, accent);
        foreground = accent;
        side = BorderSide(color: accent.withValues(alpha: 0.3), width: 0.8);
        badge = const Icon(Icons.check_rounded, size: 11);
      case LevelTileStatus.completedPerfect:
        background = GameAccents.tint(context, accent);
        foreground = accent;
        side = BorderSide(color: accent.withValues(alpha: 0.3), width: 0.8);
        badge = const Icon(Icons.star_rounded, size: 12);
    }

    return Semantics(
      label: 'Level $label, ${status.name}',
      button: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          side: side,
        ),
        child: InkWell(
          onTap: status == LevelTileStatus.locked ? null : onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 1),
                // Symbol anchors the state for color-blind users.
                IconTheme.merge(
                  data: IconThemeData(color: foreground),
                  child: SizedBox(
                    height: 12,
                    child: badge ?? (status == LevelTileStatus.current
                        ? const Icon(Icons.play_arrow_rounded, size: 12)
                        : null),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid of levels for one chapter, laid out responsively (no hardcoded
/// column count).
class LevelChapterGrid extends StatelessWidget {
  const LevelChapterGrid({
    super.key,
    required this.startLevel,
    required this.endLevel,
    required this.statusFor,
    required this.accent,
    required this.onLevelTap,
  });

  final int startLevel;
  final int endLevel;
  final LevelTileStatus Function(int level) statusFor;
  final Color accent;
  final void Function(int level) onLevelTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppDimens.space3;
        final columns =
            ((constraints.maxWidth + gap) / (AppDimens.levelTileMinSize + gap))
                .floor()
                .clamp(3, 8);
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final levels = [
          for (var level = startLevel; level <= endLevel; level++) level
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final level in levels)
              SizedBox(
                width: tileWidth,
                height: AppDimens.levelTileMinSize + 12,
                child: LevelTile(
                  level: level,
                  status: statusFor(level),
                  accent: accent,
                  onTap: () => onLevelTap(level),
                ),
              ),
          ],
        );
      },
    );
  }
}
