import 'package:flutter/material.dart';

import '../core/ads/mock_ad_service.dart';
import '../core/audio/audio_service.dart';
import '../core/haptics/haptics_service.dart';
import '../core/multiplayer/nearby_method_channel.dart';
import '../core/services/daily_service.dart';
import '../core/services/game_registry.dart';
import '../core/services/game_state_service.dart';
import '../core/services/hint_service.dart';
import '../core/services/progress_service.dart';
import '../core/services/service_scope.dart';
import '../core/services/settings_service.dart';
import '../core/storage/local_storage.dart';
import '../features/shell/app_shell.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

/// Wires storage + services + theme and hosts [AppShell].
///
/// The whole product runs offline; the ad service is the local mock and
/// never touches puzzle logic.
class ThinkrApp extends StatefulWidget {
  const ThinkrApp({super.key, required this.storage, required this.registry});

  final LocalStorage storage;
  final GameRegistry registry;

  @override
  State<ThinkrApp> createState() => _ThinkrAppState();
}

class _ThinkrAppState extends State<ThinkrApp> {
  late final AppServices _services;
  late final MockAdService _ads;

  @override
  void initState() {
    super.initState();
    final storage = widget.storage;
    final settings = SettingsService(storage);
    final progress = ProgressService(storage);
    _ads = MockAdService();
    _services = AppServices(
      storage: storage,
      registry: widget.registry,
      progress: progress,
      settings: settings,
      daily: DailyService(storage),
      ads: _ads,
      hints: HintService(storage, progress, _ads),
      haptics: HapticsService(settings),
      audio: AudioService(settings),
      gameStates: GameStateManager(storage),
      nearby: MethodChannelNearbyService(),
    );
    _services.load();
  }

  @override
  Widget build(BuildContext context) {
    return ServiceScope(
      services: _services,
      child: AnimatedBuilder(
        animation: _services.settings,
        builder: (context, _) {
          final settings = _services.settings;
          return MaterialApp(
            title: 'Thinkr',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(AppColors.light),
            darkTheme: buildAppTheme(AppColors.dark),
            themeMode: switch (settings.themeMode) {
              AppThemeMode.system => ThemeMode.system,
              AppThemeMode.light => ThemeMode.light,
              AppThemeMode.dark => ThemeMode.dark,
            },
            home: Builder(
              builder: (context) {
                // The mock ad overlay needs a navigator context.
                _ads.attach(context);
                return const AppShell();
              },
            ),
          );
        },
      ),
    );
  }
}
