import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences]. All persistence goes through
/// here so storage can be swapped (or synced to cloud later) without
/// touching features or services.
class LocalStorage {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _store =>
      _prefs ?? (throw StateError('LocalStorage.init() must be awaited first'));

  String? getString(String key) => _store.getString(key);

  Future<void> setString(String key, String value) =>
      _store.setString(key, value);

  bool getBool(String key, {bool fallback = false}) =>
      _store.getBool(key) ?? fallback;

  Future<void> setBool(String key, bool value) => _store.setBool(key, value);

  int getInt(String key, {int fallback = 0}) => _store.getInt(key) ?? fallback;

  Future<void> setInt(String key, int value) => _store.setInt(key, value);

  Future<void> remove(String key) => _store.remove(key);

  Map<String, dynamic>? getJson(String key) {
    final raw = _store.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      // Corrupt data is never fatal — treat as absent and keep playing.
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _store.setString(key, jsonEncode(value));

  /// Write without awaiting the disk flush. `SharedPreferences` updates its
  /// in-memory cache synchronously and dispatches the platform write as
  /// soon as the future is created, so the value is readable immediately
  /// and does reach disk. Used by lifecycle paths (back button, dispose,
  /// app backgrounded) where awaiting is not possible.
  void setJsonSync(String key, Map<String, dynamic> value) {
    unawaited(_store.setString(key, jsonEncode(value)));
  }

  void removeSync(String key) {
    unawaited(_store.remove(key));
  }

  /// Removes every Thinkr key (progress, settings, daily state).
  Future<void> clearAll() => _store.clear();

  /// Removes all keys starting with [prefix] (e.g. progress resets).
  Future<void> clearPrefix(String prefix) async {
    final matches =
        _store.getKeys().where((key) => key.startsWith(prefix)).toList();
    for (final key in matches) {
      await _store.remove(key);
    }
  }

  /// Keys starting with [prefix] (used by the save/resume layer to list a
  /// game's unfinished levels without knowing their keys up front).
  Set<String> keysWithPrefix(String prefix) =>
      _store.getKeys().where((key) => key.startsWith(prefix)).toSet();
}

/// Centralized keys so no service ever misspells a storage slot.
abstract final class StorageKeys {
  static const gameStatePrefix = 'gamestate.';
  static const progressPrefix = 'progress.';
  static const lastPlayed = 'progress.lastPlayed';
  static const stats = 'progress.stats';
  static const hintsPrefix = 'hints.';
  static const settings = 'settings';
  static const dailyPrefix = 'daily.';
  static const seenInstructionsPrefix = 'seen.instructions.';
  static const seenFirstNudge = 'seen.firstNudge';
}
