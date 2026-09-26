import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/models/game_definition.dart';
import '../../core/models/puzzle_session.dart';
import '../../core/services/daily_service.dart';
import '../../core/services/service_scope.dart';

/// Daily — one puzzle, one attempt set, new challenge every day.
/// Feels special without inventing a separate visual language.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key, required this.onOpenGameDetail});

  final ValueChanged<GameDefinition> onOpenGameDetail;

  @override
  Widget build(BuildContext context) {
    final services = ServiceScope.of(context);
    final daily = services.daily;
    final now = DateTime.now();
    final plan = daily.planFor(now, services.registry);
    final record = daily.recordToday(now);
    final streak = daily.streak(now);
    final history = daily.recentHistory(now);
    final text = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Daily',
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
            child: Text(
              'One puzzle. One attempt set.\nA new challenge every day.',
              style: text.bodyMedium,
            ),
          ),
          const SizedBox(height: AppDimens.space5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
            child: _DailyCard(plan: plan, record: record, streak: streak),
          ),
          SectionHeader(title: 'Last 7 days'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
            child: Row(
              children: [
                for (final entry in history)
                  Expanded(
                    child: _HistoryDot(entry: entry, accent: plan.game.accent),
                  ),
              ],
            ),
          ),
          SectionHeader(
            title: 'Today\u2019s game',
            trailing: TextActionButton(
              label: 'See game',
              onPressed: () => onOpenGameDetail(plan.game),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
            child: Text(
              '${plan.game.name} — ${plan.game.tagline}',
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

String formatDailyDate(DateTime day) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
  const weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  return '${weekdays[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.plan,
    required this.record,
    required this.streak,
  });

  final DailyPlan plan;
  final DailyRecord? record;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final done = record != null;
    return Container(
      padding: const EdgeInsets.all(AppDimens.space5),
      decoration: BoxDecoration(
        color: done ? colors.surface : GameAccents.tint(context, plan.game.accent),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(
          color: done ? colors.border : plan.game.accent.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AccentMark(accent: plan.game.accent, icon: plan.game.icon),
              const SizedBox(width: AppDimens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.game.name.toUpperCase(), style: text.labelMedium),
                    const SizedBox(height: 2),
                    Text(formatDailyDate(DateTime.now()), style: text.bodySmall),
                  ],
                ),
              ),
              if (streak > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$streak',
                      style: text.titleLarge!.copyWith(color: plan.game.accent),
                    ),
                    Text('DAY STREAK', style: text.labelSmall),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppDimens.space5),
          if (!done)
            FilledButton(
              onPressed: () => AppRouter.pushGameplay(
                context,
                PuzzleSession(game: plan.game, seed: plan.seed, isDaily: true),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: plan.game.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                ),
                textStyle: text.labelLarge,
              ),
              child: const Text('Play'),
            )
          else ...[
            Text(
              'Completed — best ${record!.moves} moves in ${record!.seconds}s',
              style: text.bodySmall,
            ),
            const SizedBox(height: AppDimens.space4),
            const SecondaryButton(label: 'Come back tomorrow', onPressed: null),
          ],
        ],
      ),
    );
  }
}

class _HistoryDot extends StatelessWidget {
  const _HistoryDot({required this.entry, required this.accent});

  final DailyHistoryEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const weekdayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: entry.isCompleted
                ? GameAccents.tint(context, accent, alpha: 0.2)
                : colors.surface,
            border: Border.all(
              color: entry.isCompleted
                  ? accent.withValues(alpha: 0.5)
                  : colors.border,
              width: 1,
            ),
          ),
          child: entry.isCompleted
              ? Icon(Icons.check_rounded, size: 14, color: accent)
              : Icon(Icons.remove_rounded, size: 14, color: colors.locked),
        ),
        const SizedBox(height: AppDimens.space2),
        Text(
          weekdayLetters[entry.day.weekday - 1],
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: entry.isCompleted ? colors.textSecondary : colors.locked,
          ),
        ),
      ],
    );
  }
}
