import 'package:flutter/foundation.dart';

import '../models/game_definition.dart';
import '../storage/local_storage.dart';
import 'game_registry.dart';

class DailyRecord {
  const DailyRecord({
    required this.gameId,
    required this.moves,
    required this.seconds,
  });

  final String gameId;
  final int moves;
  final int seconds;

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
        gameId: json['g'] as String? ?? '',
        moves: (json['m'] as num?)?.toInt() ?? 0,
        seconds: (json['s'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {'g': gameId, 'm': moves, 's': seconds};
}

/// A day's challenge plan: which game, which seed.
class DailyPlan {
  const DailyPlan({required this.game, required this.seed, required this.day});

  final GameDefinition game;
  final int seed;
  final DateTime day;
}

/// Owns the daily challenge state: today's plan, completion, streaks and
/// the recent history shown on the Daily screen. Fully offline.
class DailyService extends ChangeNotifier {
  DailyService(this._storage);

  final LocalStorage _storage;

  static String dayKey(DateTime day) =>
      '${StorageKeys.dailyPrefix}'
      '${day.year}-${day.month.monthPad}-${day.day.monthPad}';

  DailyPlan planFor(DateTime day, GameRegistry registry) {
    final available = registry.available;
    // Rotation is stable for a given date regardless of registry order
    // changes: hash the date onto the list length.
    final dayIndex = day.year * 372 + day.month * 31 + day.day;
    final game = available[dayIndex % available.length];
    return DailyPlan(
      game: game,
      seed: game.seedForDaily(day),
      day: DateTime(day.year, day.month, day.day),
    );
  }

  DailyRecord? recordFor(DateTime day) {
    final json = _storage.getJson(dayKey(day));
    return json == null ? null : DailyRecord.fromJson(json);
  }

  DailyRecord? recordToday(DateTime now) => recordFor(DateTime(now.year, now.month, now.day));

  bool isCompletedToday(DateTime now) => recordToday(now) != null;

  /// Records today's solve. Idempotent: the daily attempt set is finished
  /// once; a later solve the same day does not overwrite the first result.
  Future<bool> completeToday(
    DateTime now, {
    required String gameId,
    required int moves,
    required int seconds,
  }) async {
    final day = DateTime(now.year, now.month, now.day);
    if (recordFor(day) != null) return false;
    await _storage.setJson(
      dayKey(day),
      DailyRecord(gameId: gameId, moves: moves, seconds: seconds).toJson(),
    );
    notifyListeners();
    return true;
  }

  /// Consecutive completed days ending today (or yesterday if today isn't
  /// done yet, so the streak doesn't "reset" until the day actually passes).
  int streak(DateTime now) {
    var day = DateTime(now.year, now.month, now.day);
    if (recordFor(day) == null) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (recordFor(day) != null) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The last [count] days (oldest first) for the Daily history strip.
  List<DailyHistoryEntry> recentHistory(DateTime now, {int count = 7}) {
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(count, (index) {
      final day = today.subtract(Duration(days: count - 1 - index));
      return DailyHistoryEntry(day: day, record: recordFor(day));
    }, growable: false);
  }

  /// Used by Settings → Reset progress.
  Future<void> reset() async {
    await _storage.clearPrefix(StorageKeys.dailyPrefix);
    notifyListeners();
  }
}

class DailyHistoryEntry {
  const DailyHistoryEntry({required this.day, this.record});

  final DateTime day;
  final DailyRecord? record;

  bool get isCompleted => record != null;
}

extension on int {
  String get monthPad => toString().padLeft(2, '0');
}
