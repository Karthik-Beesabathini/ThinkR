import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

/// A row inside a [SettingsGroup]. Supports a trailing [Switch] (when
/// [value]/[onChanged] are provided) or a value label, otherwise acts as a
/// button row.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.value_ = true,
    this.onChanged,
  });

  final String label;
  final String? subtitle;

  /// Static value text (e.g. "v0.1.0").
  final String? value;

  final Widget? trailing;

  /// Tap target for button-style rows.
  final VoidCallback? onTap;

  /// Switch value — when provided together with [onChanged], the row
  /// renders a switch.
  final bool value_;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final hasSwitch = onChanged != null;

    Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.space4,
        vertical: AppDimens.space3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.bodyMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: text.bodySmall),
                ],
              ],
            ),
          ),
          if (hasSwitch)
            Switch(value: value_, onChanged: onChanged)
          else if (trailing != null)
            trailing!
          else if (value != null)
            Text(
              value!,
              style: text.bodySmall!.copyWith(color: colors.textSecondary),
            ),
        ],
      ),
    );

    if (onTap != null) {
      row = InkWell(onTap: onTap, child: row);
    }
    return row;
  }
}

/// Rounded surface container holding a column of rows with hairline
/// dividers — the standard grouped-list look.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          border: Border.all(color: colors.border, width: 0.8),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.space4,
                  ),
                  child: Container(height: 0.7, color: colors.border),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Three-way segmented control used for the theme setting.
class SettingsSegmented<T> extends StatelessWidget {
  const SettingsSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (final entry in options.entries) ...[
          if (entry != options.entries.first) const SizedBox(width: AppDimens.space2),
          Expanded(
            child: Material(
              color: entry.key == selected ? colors.primary : colors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
              child: InkWell(
                onTap: () => onSelected(entry.key),
                borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
                child: Container(
                  height: AppDimens.minTouchTarget - 8,
                  alignment: Alignment.center,
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: entry.key == selected
                          ? colors.onPrimary
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
