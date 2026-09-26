import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';
import '../buttons.dart';
import 'app_sheet.dart';

/// Two-section rules sheet — "How it works" and "How to play".
///
/// Used in two places:
///  - the first-time introduction when a game is opened for the first time
///    (from GameDetailScreen), and
///  - the "How to play" item in the gameplay menu.
/// The content comes from `GameDefinition.howItWorks` / `howToPlay`.
class HowToPlaySheet extends StatelessWidget {
  const HowToPlaySheet({
    super.key,
    required this.gameName,
    required this.howItWorks,
    required this.howToPlay,
    required this.accent,
  });

  final String gameName;
  final List<String> howItWorks;
  final List<String> howToPlay;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.space6,
              0,
              AppDimens.space6,
              AppDimens.space6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.space5),
                Text(
                  gameName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: accent,
                  ),
                ),
                const SizedBox(height: AppDimens.space4),
                _RuleSection(
                  title: 'How it works',
                  items: howItWorks,
                  accent: accent,
                ),
                const SizedBox(height: AppDimens.space5),
                _RuleSection(
                  title: 'How to play',
                  items: howToPlay,
                  accent: accent,
                ),
                const SizedBox(height: AppDimens.space6),
                PrimaryButton(
                  label: 'Got it',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  const _RuleSection({
    required this.title,
    required this.items,
    required this.accent,
  });

  final String title;
  final List<String> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: text.labelSmall),
        const SizedBox(height: AppDimens.space2),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.space2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: text.bodyMedium!.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
