import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

enum AppTab { games, multiplayer, progress, settings }

/// Compact, quiet bottom navigation. No FAB, no badges, no decoration.
/// Selected state = icon variant + ink color; unselected = muted outline.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.index,
    required this.onTap,
  });

  final int index;
  final ValueChanged<AppTab> onTap;

  static const _items = [
    (AppTab.games, 'Games', Icons.category_outlined, Icons.category_rounded),
    (AppTab.multiplayer, 'Duel', Icons.sports_esports_outlined, Icons.sports_esports_rounded),
    (AppTab.progress, 'Progress', Icons.insights_outlined, Icons.insights_rounded),
    (AppTab.settings, 'Settings', Icons.settings_outlined, Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border, width: 0.7)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppDimens.navBarHeight,
          child: Row(
            children: [
              for (final item in _items) ...[
                if (item != _items.first) const SizedBox(width: 4),
                Expanded(child: _item(context, colors, item)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context,
    AppColors colors,
    (AppTab, String, IconData, IconData) item,
  ) {
    final selected = item.$1 == AppTab.values[index];
    final color = selected ? colors.primary : colors.textSecondary;
    return InkWell(
      onTap: () => onTap(item.$1),
      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? item.$4 : item.$3, size: 22, color: color),
          const SizedBox(height: AppDimens.space1),
          Text(
            item.$2,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.2,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
