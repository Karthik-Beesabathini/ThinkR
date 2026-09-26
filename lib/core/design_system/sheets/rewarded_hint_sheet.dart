import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../buttons.dart';
import '../section_header.dart';
import 'app_sheet.dart';

/// Limits mirrored from HintService without importing it (avoids a cycle).
abstract final class HintServiceLimits {
  static const int maxHintsPerLevel = 3;
}

/// The explicit rewarded-ad exchange. The player chooses; the player can
/// always walk away. The ad itself never interrupts a puzzle.
class RewardedHintSheet extends StatelessWidget {
  const RewardedHintSheet({
    super.key,
    required this.onWatchAd,
    required this.onNotNow,
    required this.accent,
    required this.hintsRemaining,
  });

  final VoidCallback onWatchAd;
  final VoidCallback onNotNow;
  final Color accent;
  final int hintsRemaining;

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
              Icon(Icons.lightbulb_outline_rounded, color: accent, size: 28),
              const SizedBox(height: AppDimens.space3),
              Text('Get a hint', style: text.titleLarge),
              const SizedBox(height: AppDimens.space1),
              Text(
                'Watch a short ad to reveal a small clue — '
                'never the whole answer.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppDimens.space4),
              QuietChip(
                label:
                    '$hintsRemaining OF ${HintServiceLimits.maxHintsPerLevel} '
                    'HINTS LEFT',
                color: colors.textTertiary,
              ),
              const SizedBox(height: AppDimens.space5),
              PrimaryButton(
                label: 'Watch Ad',
                onPressed: onWatchAd,
                color: accent,
              ),
              TextActionButton(label: 'Not Now', onPressed: onNotNow),
            ],
          ),
        ),
      ],
    );
  }
}
