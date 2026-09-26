import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import '../../core/services/service_scope.dart';
import '../../core/services/settings_service.dart';

/// Settings — extremely simple, no decorative options.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Settings',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.space7),
        children: [
          SectionHeader(title: 'Gameplay'),
          SettingsGroup(
            children: [
              SettingsRow(
                label: 'Sound',
                value_: settings.soundOn,
                onChanged: services.settings.setSound,
              ),
              SettingsRow(
                label: 'Haptics',
                value_: settings.hapticsOn,
                onChanged: services.settings.setHaptics,
              ),
            ],
          ),
          SectionHeader(title: 'Theme'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
            child: SettingsSegmented(
              options: const {
                AppThemeMode.system: 'System',
                AppThemeMode.light: 'Light',
                AppThemeMode.dark: 'Dark',
              },
              selected: settings.themeMode,
              onSelected: services.settings.setThemeMode,
            ),
          ),
          SectionHeader(title: 'Accessibility'),
          SettingsGroup(
            children: [
              SettingsRow(
                label: 'Reduced motion',
                subtitle: 'Minimizes animations and transitions.',
                value_: settings.reducedMotion,
                onChanged: services.settings.setReducedMotion,
              ),
            ],
          ),
          SectionHeader(title: 'Data'),
          SettingsGroup(
            children: [
              SettingsRow(
                label: 'Reset progress',
                subtitle:
                    'Clears levels, daily history and hints. Cannot be undone.',
                onTap: () => _confirmReset(context),
              ),
            ],
          ),
          SectionHeader(title: 'About'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              0,
              AppDimens.pagePadding,
              0,
            ),
            child: SettingsGroup(
              children: [
                SettingsRow(label: 'Version', value: '0.1.0'),
                SettingsRow(label: 'Offline', value: 'Fully'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.space4,
              AppDimens.pagePadding,
              0,
            ),
            child: Text(
              'Thinkr plays entirely offline. Your progress stays on this '
              'device and is never shared.',
              style: text.bodySmall!.copyWith(color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    final text = Theme.of(context).textTheme;
    showAppSheet(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          SheetBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.space5),
                Text('Reset all progress?', style: text.titleLarge),
                const SizedBox(height: AppDimens.space1),
                Text(
                  'Every level, daily result and hint will be cleared. '
                  'Settings are kept.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppDimens.space6),
                PrimaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(sheetContext),
                ),
                TextActionButton(
                  label: 'Reset Everything',
                  color: context.colors.error,
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await services.progress.resetProgress();
                    await services.daily.reset();
                    await services.gameStates.clearAllGames();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
