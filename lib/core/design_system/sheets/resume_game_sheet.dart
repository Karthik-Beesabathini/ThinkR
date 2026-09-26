import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';
import '../../../core/utils/formatters.dart' show formatPlayTime;
import '../buttons.dart';
import 'app_sheet.dart';

/// "Continue your game?" — shown when a level has an unfinished attempt.
///
/// Tapping a level tile must never silently throw away matched work, so the
/// player explicitly chooses between resuming the exact saved state and
/// starting the level over.
class ResumeGameSheet extends StatelessWidget {
  const ResumeGameSheet({
    super.key,
    required this.gameName,
    required this.level,
    required this.moves,
    required this.seconds,
    required this.accent,
    required this.onContinue,
    required this.onRestart,
  });

  final String gameName;
  final int level;
  final int moves;
  final int seconds;
  final Color accent;
  final VoidCallback onContinue;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
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
              Text('Continue your game?', style: text.titleLarge),
              const SizedBox(height: AppDimens.space1),
              Text(
                '$gameName · Level $level\n'
                '$moves moves · ${formatPlayTime(seconds)}',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppDimens.space6),
              PrimaryButton(
                label: 'Continue',
                color: accent,
                onPressed: onContinue,
              ),
              SecondaryButton(label: 'Restart', onPressed: onRestart),
            ],
          ),
        ),
      ],
    );
  }
}
