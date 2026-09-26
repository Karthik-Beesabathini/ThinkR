import 'package:flutter/services.dart';

import '../services/settings_service.dart';

/// Centralized, settings-aware haptics. Games never call the platform
/// channel directly.
///
/// The base levels (tap/light/success/warning) are used by the shell;
/// the *flavored* methods let each game carry its own tactile
/// personality without any of them touching the platform directly.
class HapticsService {
  HapticsService(this._settings);

  final SettingsService _settings;

  void _fire(void Function() feedback) {
    if (_settings.hapticsOn) feedback();
  }

  void tap() => _fire(HapticFeedback.selectionClick);
  void lightImpact() => _fire(HapticFeedback.lightImpact);
  void success() => _fire(HapticFeedback.mediumImpact);
  void warning() => _fire(HapticFeedback.heavyImpact);

  // --- per-game flavors -----------------------------------------------------

  /// Shift — a solid mechanical thock when a tile slides into the gap.
  void slide() => _fire(HapticFeedback.mediumImpact);

  /// Lights — a soft blip when a tile flips.
  void flip() => _fire(HapticFeedback.selectionClick);

  /// Memory — a crisp double-tick when a cell matches.
  void cellMatch() => _fire(HapticFeedback.lightImpact);

  /// Memory duel — a turn hand-off pulse between players.
  void turnHandoff() => _fire(HapticFeedback.selectionClick);
}
