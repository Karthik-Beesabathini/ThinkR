import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../models/game_definition.dart';

/// Prominent "pick up where you left off" card.
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    super.key,
    required this.game,
    required this.level,
    required this.solvedCount,
    required this.onTap,
  });

  final GameDefinition game;
  final int level;
  final int solvedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Material(
        color: GameAccents.tint(context, game.accent),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.space5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONTINUE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.6,
                          color: game.accent,
                        ),
                      ),
                      const SizedBox(height: AppDimens.space1),
                      Text(
                        '${game.name} · Level $level',
                        style: Theme.of(context).textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$solvedCount / ${game.totalLevels} solved',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppDimens.space3),
                Container(
                  width: AppDimens.minTouchTarget,
                  height: AppDimens.minTouchTarget,
                  decoration: BoxDecoration(
                    color: game.accent,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  ),
                  child:
                      const Icon(Icons.play_arrow_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
