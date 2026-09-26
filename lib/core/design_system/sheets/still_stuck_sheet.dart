import 'package:flutter/material.dart';

import '../../../app/theme/app_dimens.dart';
import '../buttons.dart';
import 'app_sheet.dart';

/// Shown once, quietly, after ~3 failed attempts. Never forces anything.
class StillStuckSheet extends StatelessWidget {
  const StillStuckSheet({
    super.key,
    required this.onGetHint,
    required this.onKeepTrying,
    required this.accent,
  });

  final VoidCallback onGetHint;
  final VoidCallback onKeepTrying;
  final Color accent;

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
              Text('Still stuck?', style: text.titleLarge),
              const SizedBox(height: AppDimens.space1),
              Text(
                "You've tried a few times.\n"
                'A hint can point you in the right direction — without '
                'giving the answer away.',
                style: text.bodySmall,
              ),
              const SizedBox(height: AppDimens.space6),
              PrimaryButton(label: 'Get a Hint', onPressed: onGetHint, color: accent),
              TextActionButton(label: 'Keep Trying', onPressed: onKeepTrying),
            ],
          ),
        ),
      ],
    );
  }
}
