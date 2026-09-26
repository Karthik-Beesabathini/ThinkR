import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

/// Shared screen scaffold: background color + safe areas + optional
/// compact top bar. Tab screens with custom heroes pass [title] as null
/// and build their own header inside [body].
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.leading,
    this.actions,
    required this.body,
  });

  /// Uppercase micro-label style when provided.
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.space2,
                  AppDimens.space2,
                  AppDimens.space2,
                  0,
                ),
                child: SizedBox(
                  height: AppDimens.minTouchTarget,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (leading != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: leading!,
                        ),
                      Text(
                        title!.toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium!.copyWith(
                              color: colors.textSecondary,
                              letterSpacing: 2,
                            ),
                      ),
                      if (actions != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// Standard quiet back button. Named to avoid clashing with Material's
/// BackButton when both are imported.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed, this.color});

  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      icon: Icon(Icons.arrow_back_rounded, color: color ?? context.colors.textPrimary),
      tooltip: 'Back',
    );
  }
}
