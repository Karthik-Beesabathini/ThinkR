import 'package:flutter/foundation.dart';

import '../storage/local_storage.dart';

enum AppThemeMode { system, light, dark }

class SettingsService extends ChangeNotifier {
  SettingsService(this._storage);

  final LocalStorage _storage;

  bool soundOn = true;
  bool hapticsOn = true;
  bool reducedMotion = false;
  AppThemeMode themeMode = AppThemeMode.system;

  void setSound(bool value) => _set(() => soundOn = value);
  void setHaptics(bool value) => _set(() => hapticsOn = value);
  void setReducedMotion(bool value) => _set(() => reducedMotion = value);

  void setThemeMode(AppThemeMode mode) => _set(() => themeMode = mode);

  /// Motion-aware duration. Used by every animation in the app so the
  /// "reduced motion" accessibility setting is honored globally.
  Duration motion([int milliseconds = 200]) => reducedMotion
      ? const Duration(milliseconds: 1)
      : Duration(milliseconds: milliseconds);

  void load() {
    final json = _storage.getJson(StorageKeys.settings);
    if (json == null) return;
    soundOn = json['sound'] as bool? ?? true;
    hapticsOn = json['haptics'] as bool? ?? true;
    reducedMotion = json['reducedMotion'] as bool? ?? false;
    final themeIndex = (json['theme'] as num?)?.toInt() ?? 0;
    themeMode = AppThemeMode
        .values[themeIndex.clamp(0, AppThemeMode.values.length - 1)];
  }

  void _set(VoidCallback change) {
    change();
    _storage.setJson(StorageKeys.settings, {
      'sound': soundOn,
      'haptics': hapticsOn,
      'reducedMotion': reducedMotion,
      'theme': themeMode.index,
    });
    notifyListeners();
  }
}
