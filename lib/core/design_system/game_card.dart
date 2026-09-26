import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../models/game_definition.dart';
import 'section_header.dart';

/// A game entry on the home screen. Communicates name, one-line promise,
/// progress, and 2P support — nothing else.
class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    required this.progress,
    this.onTap,
  });

  final GameDefinition game;

  /// Solved levels (0..totalLevels).
  final int progress;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.pagePadding,
        0,
        AppDimens.pagePadding,
        AppDimens.space3,
      ),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(AppDimens.space4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
              border: Border.all(color: colors.border, width: 0.8),
            ),
            child: Row(
              children: [
                AccentMark(accent: game.accent, icon: game.icon),
                const SizedBox(width: AppDimens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name.toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        game.tagline,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimens.space3),
                      Row(
                        children: [
                          Text(
                            '$progress / ${game.totalLevels}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.4,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: AppDimens.space3),
                          Expanded(
                            child: ProgressTrack(
                              value: game.totalLevels == 0
                                  ? 0
                                  : progress / game.totalLevels,
                              color: game.accent,
                            ),
                          ),
                          if (game.supportsTwoPlayer) ...[
                            const SizedBox(width: AppDimens.space3),
                            QuietChip(label: '2P', color: game.accent),
                          ],
                        ],
                      ),
                    ],
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

/// A quiet row for games that aren't available yet ("More games").
class ComingSoonRow extends StatelessWidget {
  const ComingSoonRow({super.key, required this.game});

  final GameDefinition game;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.pagePadding,
        vertical: AppDimens.space2,
      ),
      child: Row(
        children: [
          Icon(game.icon, size: 18, color: colors.locked),
          const SizedBox(width: AppDimens.space3),
          Expanded(
            child: Text(
              game.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(color: colors.textSecondary),
            ),
          ),
          QuietChip(label: 'SOON', color: colors.textTertiary),
        ],
      ),
    );
  }
}

/// Small rounded accent mark with the game's icon.
class AccentMark extends StatelessWidget {
  const AccentMark({super.key, required this.accent, required this.icon});

  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}
