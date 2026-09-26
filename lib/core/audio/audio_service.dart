import 'package:flutter/services.dart';

import '../services/settings_service.dart';

/// Settings-aware audio feedback.
///
/// v1 plays native system sounds (no assets, no plugin, instant). The
/// interface is the real contract: swap the bodies for a proper sound
/// pack later without touching call sites. Games never call the platform
/// directly — the shell resolves game-specific flavors.
class AudioService {
  AudioService(this._settings);

  final SettingsService _settings;

  bool get _enabled => _settings.soundOn;

  void _play(SystemSoundType type) {
    if (!_enabled) return;
    // TODO(core): replace with a small bundled sound pack; SystemSound
    // gives a zero-dependency, always-available baseline today.
    SystemSound.play(type);
  }

  /// Generic quiet move tick.
  void tap() => _play(SystemSoundType.click);

  /// Lights — a tile flipped.
  void flip() => _play(SystemSoundType.click);

  /// Shift — a tile slid into the gap.
  void slide() => _play(SystemSoundType.click);

  /// Memory — a cell matched.
  void match() => _play(SystemSoundType.click);

  /// An incorrect action. Kept quiet; the heavy haptic carries the weight.
  void miss() => _play(SystemSoundType.click);

  /// Level solved.
  void success() => _play(SystemSoundType.alert);
}
