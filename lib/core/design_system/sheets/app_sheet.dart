import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';

/// Shared bottom-sheet host. Every sheet in the app looks identical:
/// rounded top, drag handle, surface background, safe-area padding.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: context.colors.scrim,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetContext.colors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusSheet),
          ),
        ),
        child: SafeArea(top: false, child: builder(sheetContext)),
      ),
    ),
  );
}

/// Drag handle at the top of every sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: AppDimens.space3),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: context.colors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Standard sheet body padding + handle.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.space6,
        0,
        AppDimens.space6,
        AppDimens.space6,
      ),
      child: child,
    );
  }
}

/// Quiet inline banner used for hint reveals and soft feedback.
class InlineBanner extends StatelessWidget {
  const InlineBanner({super.key, required this.message, required this.accent});

  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space4,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: GameAccents.tint(context, accent, alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        border: Border.all(color: accent.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, size: 16, color: accent),
          const SizedBox(width: AppDimens.space2),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
