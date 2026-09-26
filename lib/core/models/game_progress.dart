/// Per-level completion record. Kept minimal: best result only.
class LevelRecord {
  const LevelRecord({
    required this.moves,
    required this.seconds,
    this.perfect = false,
  });

  final int moves;
  final int seconds;
  final bool perfect;

  factory LevelRecord.fromJson(Map<String, dynamic> json) => LevelRecord(
        moves: (json['m'] as num?)?.toInt() ?? 0,
        seconds: (json['s'] as num?)?.toInt() ?? 0,
        perfect: json['p'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'m': moves, 's': seconds, 'p': perfect};

  /// Keeps the *better* result: fewer moves wins; a perfect solve wins over
  /// a non-perfect one with the same move count.
  LevelRecord betterOf(LevelRecord other) {
    if (perfect != other.perfect) return perfect ? this : other;
    if (moves != other.moves) return moves < other.moves ? this : other;
    return seconds <= other.seconds ? this : other;
  }
}

/// Progress for a single game. Pure data — persistence lives in
/// [ProgressService].
class GameProgressData {
  GameProgressData({Map<int, LevelRecord>? completed})
      : completed = completed ?? {};

  final Map<int, LevelRecord> completed;

  bool isCompleted(int level) => completed.containsKey(level);

  /// First unsolved level — the one "Continue" points at.
  int get currentLevel {
    var level = 1;
    while (completed.containsKey(level)) {
      level++;
    }
    return level;
  }

  bool isUnlocked(int level) => level == 1 || completed.containsKey(level - 1);

  int get solvedCount => completed.length;

  int get maxLevelSolved =>
      completed.keys.fold(0, (max, level) => level > max ? level : max);

  Map<String, dynamic> toJson() => {
        for (final entry in completed.entries)
          entry.key.toString(): entry.value.toJson(),
      };

  static GameProgressData fromJson(Map<String, dynamic>? json) {
    final data = GameProgressData();
    if (json == null) return data;
    json.forEach((key, value) {
      final level = int.tryParse(key);
      if (level != null && value is Map<String, dynamic>) {
        data.completed[level] = LevelRecord.fromJson(value);
      }
    });
    return data;
  }
}
