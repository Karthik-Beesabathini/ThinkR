import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/models/game_definition.dart';
import '../../core/models/puzzle_session.dart';
import '../../core/services/service_scope.dart';

/// Games — the primary landing experience. Continue first, then the list.
/// Start playing within seconds; nothing else competes for attention.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenGameDetail});

  final ValueChanged<GameDefinition> onOpenGameDetail;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final services = ServiceScope.of(context);
    final registry = services.registry;
    final progress = services.progress;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final available = registry.available;

    // Continue target: last played game, else the first available game.
    GameDefinition? continueGame;
    for (final game in available) {
      if (game.id == progress.lastGameId) continueGame = game;
    }
    continueGame ??= available.isEmpty ? null : available.first;

    return AppScaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: AppDimens.space7),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.space6,
              AppDimens.pagePadding,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: text.bodySmall!.copyWith(
                    color: colors.textTertiary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppDimens.space1),
                Text('Thinkr', style: text.displaySmall),
              ],
            ),
          ),
          const SizedBox(height: AppDimens.space5),
          _DailyChallengeCard(),
          const SizedBox(height: AppDimens.space4),
          if (continueGame != null)
            ContinueCard(
              game: continueGame,
              level: progress.continueLevel(continueGame),
              solvedCount: progress.progressOf(continueGame).solvedCount,
              onTap: () => onOpenGameDetail(continueGame!),
            ),
          SectionHeader(title: 'Games'),
          for (final game in available)
            GameCard(
              game: game,
              progress: progress.progressOf(game).solvedCount,
              onTap: () => onOpenGameDetail(game),
            ),
          if (registry.comingSoon.isNotEmpty) ...[
            SectionHeader(title: 'More games'),
            for (final game in registry.comingSoon) ComingSoonRow(game: game),
          ],
        ],
      ),
    );
  }
}

/// Compact daily-challenge entry so the rotation + streak loop stays
/// visible after the Daily tab became the Duel tab. Quiet until done —
/// then it says so and stands down for the day.
class _DailyChallengeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final services = ServiceScope.of(context);
    final daily = services.daily;
    final now = DateTime.now();
    final plan = daily.planFor(now, services.registry);
    final record = daily.recordToday(now);
    final streak = daily.streak(now);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final done = record != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Material(
        color: GameAccents.tint(context, plan.game.accent, alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          onTap: done
              ? null
              : () => AppRouter.pushGameplay(
                    context,
                    PuzzleSession(
                      game: plan.game,
                      seed: plan.seed,
                      isDaily: true,
                    ),
                  ),
          child: Container(
            padding: const EdgeInsets.all(AppDimens.space4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
              border: Border.all(
                color: plan.game.accent.withValues(alpha: 0.30),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                AccentMark(accent: plan.game.accent, icon: plan.game.icon),
                const SizedBox(width: AppDimens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        done ? 'DAILY COMPLETE' : 'TODAY\u2019S CHALLENGE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: plan.game.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        done
                            ? '${plan.game.name} — best ${record.moves} moves. '
                                'Come back tomorrow.'
                            : '${plan.game.name} — ${plan.game.tagline}',
                        style: text.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (streak > 0) ...[
                  const SizedBox(width: AppDimens.space2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$streak',
                        style: text.titleMedium!
                            .copyWith(color: plan.game.accent),
                      ),
                      Text('DAY', style: text.labelSmall),
                    ],
                  ),
                ] else
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textTertiary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
