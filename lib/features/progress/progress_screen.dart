import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import '../../core/models/game_definition.dart';
import '../../core/services/service_scope.dart';

/// Progress — the player's journey in plain numbers. No charts for the
/// sake of charts, no fake IQ scores.
class ProgressScreen extends StatelessWidget {
  const ProgressScreen({
    super.key,
    required this.onPlayRequested,
    required this.onOpenGameDetail,
  });

  /// Called when the empty state's "Play a Game" button is pressed.
  final VoidCallback onPlayRequested;
  final ValueChanged<GameDefinition> onOpenGameDetail;

  @override
  Widget build(BuildContext context) {
    final services = ServiceScope.of(context);
    final registry = services.registry;
    final progress = services.progress;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final available = registry.available;
    final solvedTotal = available.fold<int>(
      0,
      (sum, game) => sum + progress.progressOf(game).solvedCount,
    );
    final levelTotal = available.fold<int>(
      0,
      (sum, game) => sum + game.totalLevels,
    );

    if (solvedTotal == 0) {
      return AppScaffold(
        title: 'Progress',
        body: EmptyState(
          title: 'Your journey starts here.',
          message: 'Solve your first level and your progress\n'
              'will appear here.',
          buttonLabel: 'Play a Game',
          onButton: onPlayRequested,
        ),
      );
    }

    return AppScaffold(
      title: 'Progress',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.space7),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.space5,
              AppDimens.pagePadding,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppDimens.space5),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
                border: Border.all(color: colors.border, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OVERALL', style: text.labelSmall),
                  const SizedBox(height: AppDimens.space2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$solvedTotal', style: text.displaySmall),
                      Text(' / $levelTotal levels', style: text.bodySmall),
                    ],
                  ),
                  const SizedBox(height: AppDimens.space4),
                  ProgressTrack(
                    value: levelTotal == 0 ? 0 : solvedTotal / levelTotal,
                    height: 6,
                  ),
                ],
              ),
            ),
          ),
          SectionHeader(title: 'Games'),
          for (final game in available)
            _GameProgressRow(
              game: game,
              solved: progress.progressOf(game).solvedCount,
              onTap: () => onOpenGameDetail(game),
            ),
          SectionHeader(title: 'Your record'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
            child: SettingsGroup(
              children: [
                SettingsRow(label: 'Levels solved', value: '${progress.totalSolved}'),
                SettingsRow(label: 'Hints used', value: '${progress.hintsUsed}'),
                SettingsRow(
                  label: 'Current streak',
                  value: '${services.daily.streak(DateTime.now())} days',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.space4,
              AppDimens.pagePadding,
              0,
            ),
            child: Text(
              'Thinkr measures puzzles, not intelligence.\n'
              'There are no scores here — only solved levels.',
              style: text.bodySmall!.copyWith(color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameProgressRow extends StatelessWidget {
  const _GameProgressRow({
    required this.game,
    required this.solved,
    required this.onTap,
  });

  final GameDefinition game;
  final int solved;
  final VoidCallback onTap;

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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.space2),
          child: Row(
            children: [
              AccentMark(accent: game.accent, icon: game.icon),
              const SizedBox(width: AppDimens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '$solved / ${game.totalLevels}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimens.space2),
                    ProgressTrack(
                      value: game.totalLevels == 0 ? 0 : solved / game.totalLevels,
                      color: game.accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
