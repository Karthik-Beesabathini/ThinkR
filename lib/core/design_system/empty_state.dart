import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import 'buttons.dart';

/// Calm, honest empty state. No fake charts, no decoration.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onButton,
    this.icon = Icons.grid_view_rounded,
  });

  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onButton;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: colors.locked),
            const SizedBox(height: AppDimens.space4),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppDimens.space2),
            Text(
              message,
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (buttonLabel != null && onButton != null) ...[
              const SizedBox(height: AppDimens.space6),
              SizedBox(
                width: 220,
                child: PrimaryButton(label: buttonLabel!, onPressed: onButton),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Calm error state — no technical jargon, progress is never dramatic.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.onRetry,
    this.message = 'Something went wrong.\nYour local progress is safe.',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Something went wrong',
      message: message,
      buttonLabel: 'Try Again',
      onButton: onRetry,
    );
  }
}
