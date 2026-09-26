import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../buttons.dart';
import 'app_sheet.dart';

/// Compact "solved" state. Reinforces "I solved it" without celebration
/// overload: one label, the milestone, the numbers, one obvious next action.
class CompletionData {
  const CompletionData({
    required this.title,
    required this.stats,
    this.note,
    this.badge,
    this.primaryLabel = 'Next Level',
    this.secondaryLabel = 'Replay',
  });

  /// e.g. "Level 27" or "Daily complete".
  final String title;

  /// (label, value) pairs: moves, time, …
  final List<(String, String)> stats;

  /// Optional quiet line (e.g. "Player 1 wins 4–2").
  final String? note;

  /// Optional achievement line under the title (e.g. "Perfect — the
  /// minimum 12 moves"). Rendered as an accent-tinted chip.
  final String? badge;

  final String primaryLabel;
  final String? secondaryLabel;
}

class GameCompletionSheet extends StatelessWidget {
  const GameCompletionSheet({
    super.key,
    required this.data,
    required this.accent,
    required this.onPrimary,
    this.onSecondary,
  });

  final CompletionData data;
  final Color accent;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetHandle(),
        SheetBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDimens.space5),
              Text(
                'SOLVED',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: accent,
                ),
              ),
              const SizedBox(height: AppDimens.space2),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: text.displaySmall,
              ),
              if (data.badge != null) ...[
                const SizedBox(height: AppDimens.space2),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimens.space3,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: GameAccents.tint(context, accent, alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppDimens.radiusPill,
                      ),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: accent),
                        const SizedBox(width: 4),
                        Text(
                          data.badge!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (data.note != null) ...[
                const SizedBox(height: AppDimens.space1),
                Text(
                  data.note!,
                  textAlign: TextAlign.center,
                  style: text.bodySmall,
                ),
              ],
              const SizedBox(height: AppDimens.space5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final (index, stat) in data.stats.indexed) ...[
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.space5,
                        ),
                        child: Container(
                          width: 1,
                          height: 28,
                          color: colors.border,
                        ),
                      ),
                    Column(
                      children: [
                        Text(stat.$2, style: text.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          stat.$1.toUpperCase(),
                          style: text.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppDimens.space6),
              PrimaryButton(label: data.primaryLabel, onPressed: onPrimary),
              if (data.secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: AppDimens.space2),
                TextActionButton(
                  label: data.secondaryLabel!,
                  onPressed: onSecondary,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
