import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/puzzle_session.dart';
import '../storage/local_storage.dart';

/// A snapshot of an unfinished level, persisted so the player can leave
/// mid-level and continue exactly where they stopped.
///
/// [moves]/[seconds] come from the gameplay shell; [details] is the
/// game-specific payload produced by the board (card layout, found cells,
/// lights grid, tiles, …). Serialization of [details] lives with each
/// game — this layer only stores opaque maps.
class SavedGameState {
  const SavedGameState({
    required this.gameId,
    required this.level,
    required this.moves,
    required this.seconds,
    required this.details,
    required this.savedAt,
  });

  final String gameId;
  final int level;
  final int moves;
  final int seconds;
  final Map<String, dynamic> details;
  final DateTime savedAt;

  bool get isEmptyAttempt => moves == 0 && seconds == 0 && details.isEmpty;

  factory SavedGameState.fromJson(String gameId, Map<String, dynamic> json) {
    return SavedGameState(
      gameId: gameId,
      level: (json['level'] as num?)?.toInt() ?? 0,
      moves: (json['moves'] as num?)?.toInt() ?? 0,
      seconds: (json['seconds'] as num?)?.toInt() ?? 0,
      details: (json['details'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['at'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'moves': moves,
        'seconds': seconds,
        'details': details,
        'at': savedAt.millisecondsSinceEpoch,
      };

  /// The payload the gameplay shell restores from. Keeps the persistence
  /// layer and the session model decoupled: this is the only place the two
  /// meet.
  LevelResumeState toResumeState() => LevelResumeState(
        moves: moves,
        seconds: seconds,
        details: details,
      );
}

/// Reusable save/resume layer for in-progress levels (Memory, Lights,
/// Shift and future games).
///
/// One save slot per game + level, stored in the app's existing local
/// storage — no new dependencies, no network, no Firebase. Notifies
/// listeners so a visible "Continue your game?" affordance refreshes when
/// saves appear or disappear.
class GameStateManager extends ChangeNotifier {
  GameStateManager(this._storage);

  final LocalStorage _storage;

  static String _key(String gameId, int level) =>
      '${StorageKeys.gameStatePrefix}$gameId.$level';

  bool hasSavedGame(String gameId) =>
      _storage
          .keysWithPrefix('${StorageKeys.gameStatePrefix}$gameId.')
          .isNotEmpty;

  /// True when *any* game has an unfinished level saved.
  bool get hasAnySavedGame =>
      _storage.keysWithPrefix(StorageKeys.gameStatePrefix).isNotEmpty;

  /// Resolves what opening a game should do, without the UI having to
  /// know about levels or storage keys: the unfinished attempt when one
  /// exists (so it can be offered as "Continue your game?"), otherwise the
  /// requested level.
  SavedGameState? resumeGame(String gameId, int level) =>
      loadGameState(gameId, level);

  SavedGameState? loadGameState(String gameId, int level) {
    final json = _storage.getJson(_key(gameId, level));
    if (json == null) return null;
    return SavedGameState.fromJson(gameId, json);
  }

  /// Most recent save across all of a game's levels — used by the
  /// "Continue your game?" card on the game detail screen.
  SavedGameState? latestSavedGame(String gameId) {
    final levelPrefix = '${StorageKeys.gameStatePrefix}$gameId.';
    SavedGameState? latest;
    for (final key in _storage.keysWithPrefix(levelPrefix)) {
      final suffix = key.substring(levelPrefix.length);
      final level = int.tryParse(suffix);
      if (level == null) continue;
      final state = loadGameState(gameId, level);
      if (state == null) continue;
      if (latest == null || state.savedAt.isAfter(latest.savedAt)) {
        latest = state;
      }
    }
    return latest;
  }

  /// Persists via [LocalStorage.setJson], which writes synchronously and
  /// serializes its own disk flush internally. Deliberately fire-and-forget
  /// at the call site: saving from `dispose()` must not depend on the
  /// event loop turning, because the shell is being torn down.
  Future<void> saveGameState(SavedGameState state) async {
    await _storage.setJson(_key(state.gameId, state.level), state.toJson());
    notifyListeners();
  }

  /// Synchronous variant used by lifecycle paths (back button, dispose,
  /// app backgrounded) where awaiting could drop the save.
  void saveGameStateSync(SavedGameState state) {
    _storage.setJsonSync(_key(state.gameId, state.level), state.toJson());
    // Notification is deferred: callers run inside dispose()/pop handlers,
    // where an immediate notifyListeners() could rebuild a widget tree
    // that is mid-teardown.
    scheduleMicrotask(notifyListeners);
  }

  Future<void> clearGameState(String gameId, int level) async {
    await _storage.remove(_key(gameId, level));
    notifyListeners();
  }

  /// Synchronous clear used by the completion handler so a solved level
  /// can never be offered as "Continue your game?" a frame later.
  void clearGameStateSync(String gameId, int level) {
    _storage.removeSync(_key(gameId, level));
    scheduleMicrotask(notifyListeners);
  }

  /// Used by Settings → Reset progress.
  Future<void> clearAllGames() async {
    await _storage.clearPrefix(StorageKeys.gameStatePrefix);
    notifyListeners();
  }
}
