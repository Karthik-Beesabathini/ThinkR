import 'package:flutter/foundation.dart';

import '../models/game_definition.dart';
import '../models/game_progress.dart';
import '../storage/local_storage.dart';
import 'game_registry.dart';

/// Owns all level progress, per-game and global stats, and the "continue"
/// pointer. Independent from UI; persistence goes through [LocalStorage].
class ProgressService extends ChangeNotifier {
  ProgressService(this._storage);

  final LocalStorage _storage;

  final Map<String, GameProgressData> _byGame = {};

  String? lastGameId;
  int? lastLevel;
  DateTime? lastPlayedAt;

  int totalSolved = 0;
  int hintsUsed = 0;

  GameProgressData progressOf(GameDefinition game) =>
      _byGame.putIfAbsent(game.id, () => GameProgressData());

  bool isGameComplete(GameDefinition game) =>
      progressOf(game).solvedCount >= game.totalLevels;

  /// The level "Continue" should open: where the player left off, or the
  /// next unsolved level when they already finished that one.
  int continueLevel(GameDefinition game) {
    final progress = progressOf(game);
    final last = lastGameId == game.id ? lastLevel : null;
    if (last != null && !progress.isCompleted(last)) return last;
    return progress.currentLevel.clamp(1, game.totalLevels);
  }

  bool get hasAnyProgress => totalSolved > 0;

  void recordLevelResult(
    GameDefinition game, {
    required int level,
    required int moves,
    required int seconds,
    required bool perfect,
  }) {
    final progress = progressOf(game);
    if (progress.isCompleted(level)) {
      final existing = progress.completed[level]!;
      final candidate = LevelRecord(
        moves: moves,
        seconds: seconds,
        perfect: perfect || existing.perfect,
      );
      progress.completed[level] = existing.betterOf(candidate);
    } else {
      progress.completed[level] = LevelRecord(
        moves: moves,
        seconds: seconds,
        perfect: perfect,
      );
      totalSolved++;
    }

    lastGameId = game.id;
    lastLevel = level;
    lastPlayedAt = DateTime.now();
    _persist(game);
    notifyListeners();
  }

  void recordHintUsed() {
    hintsUsed++;
    _persistStats();
  }

  void markLastPlayed(GameDefinition game, int level) {
    lastGameId = game.id;
    lastLevel = level;
    lastPlayedAt = DateTime.now();
    _persistStats();
  }

  /// Wipes all progress (settings survive). Used by Settings → Data.
  Future<void> resetProgress() async {
    _byGame.clear();
    lastGameId = null;
    lastLevel = null;
    lastPlayedAt = null;
    totalSolved = 0;
    hintsUsed = 0;
    await _storage.remove(StorageKeys.lastPlayed);
    await _storage.remove(StorageKeys.stats);
    notifyListeners();
  }

  void load(GameRegistry registry) {
    for (final game in registry.games) {
      final json = _storage.getJson('${StorageKeys.progressPrefix}${game.id}');
      _byGame[game.id] = GameProgressData.fromJson(json);
    }
    final last = _storage.getJson(StorageKeys.lastPlayed);
    lastGameId = last?['game'] as String?;
    lastLevel = (last?['level'] as num?)?.toInt();
    final playedAt = (last?['at'] as num?)?.toInt();
    lastPlayedAt =
        playedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(playedAt);
    final stats = _storage.getJson(StorageKeys.stats);
    totalSolved = (stats?['solved'] as num?)?.toInt() ?? 0;
    hintsUsed = (stats?['hints'] as num?)?.toInt() ?? 0;
  }

  void _persist(GameDefinition game) {
    _storage.setJson(
      '${StorageKeys.progressPrefix}${game.id}',
      progressOf(game).toJson(),
    );
    _persistStats();
  }

  void _persistStats() {
    _storage.setJson(StorageKeys.lastPlayed, {
      if (lastGameId != null) 'game': lastGameId,
      if (lastLevel != null) 'level': lastLevel,
      if (lastPlayedAt != null)
        'at': lastPlayedAt!.millisecondsSinceEpoch,
    });
    _storage.setJson(StorageKeys.stats, {
      'solved': totalSolved,
      'hints': hintsUsed,
    });
  }
}
