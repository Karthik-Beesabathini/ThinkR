import 'package:flutter/material.dart';

import '../ads/ad_service.dart';
import '../audio/audio_service.dart';
import '../haptics/haptics_service.dart';
import '../multiplayer/nearby_connections_service.dart';
import '../storage/local_storage.dart';
import 'daily_service.dart';
import 'game_registry.dart';
import 'game_state_service.dart';
import 'hint_service.dart';
import 'progress_service.dart';
import 'settings_service.dart';

/// Every long-lived service, provided once at the root.
class AppServices {
  AppServices({
    required this.storage,
    required this.registry,
    required this.progress,
    required this.settings,
    required this.daily,
    required this.ads,
    required this.hints,
    required this.haptics,
    required this.audio,
    required this.gameStates,
    required this.nearby,
  });

  final LocalStorage storage;
  final GameRegistry registry;
  final ProgressService progress;
  final SettingsService settings;
  final DailyService daily;
  final AdService ads;
  final HintService hints;
  final HapticsService haptics;
  final AudioService audio;
  final GameStateManager gameStates;

  /// Nearby peer-to-peer play. Interface + mock today; the Android
  /// MethodChannel implementation rides behind the same contract.
  final NearbyConnectionsService nearby;

  /// Loads persisted state. Call once before the first frame.
  void load() {
    settings.load();
    progress.load(registry);
  }

  Listenable get listenable => Listenable.merge([
        progress,
        settings,
        daily,
        gameStates,
      ]);
}

/// Inherited [AppServices] with rebuild-on-change semantics for the screens
/// that display persisted state. Game boards never depend on this.
class ServiceScope extends InheritedNotifier {
  ServiceScope({
    required AppServices services,
    required super.child,
    super.key,
  })  : _services = services,
        super(notifier: services.listenable);


  final AppServices _services;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ServiceScope>()!._services;
}
