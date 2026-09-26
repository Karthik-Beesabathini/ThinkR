import 'dart:math';

/// Memory Matrix logic. A grid flashes a pattern of cells; the player must
/// reproduce it. Patterns grow with the level; the reveal window shrinks.
class MemoryPuzzle {
  MemoryPuzzle({required int level, required int seed})
      : size = _sizeForLevel(level),
        patternCount = patternCountForLevel(level),
        cellsPerPattern = (3 + level ~/ 6).clamp(3, 9) {
    final rng = Random(seed);
    final total = size * size;
    final allCells = List.generate(total, (i) => i)..shuffle(rng);
    // Windows wrap around the shuffled ring so every pattern always has
    // exactly [cellsPerPattern] cells, even for late levels where
    // patternCount * cellsPerPattern exceeds the grid size.
    patterns = [
      for (var p = 0; p < patternCount; p++)
        {
          for (var j = 0; j < cellsPerPattern; j++)
            allCells[(p * cellsPerPattern + j) % total],
        },
    ];
  }

  final int size;

  /// Number of sequential patterns to reproduce.
  final int patternCount;

  /// How many cells light up per pattern.
  final int cellsPerPattern;

  late final List<Set<int>> patterns;

  int _current = 0;
  Set<int> _playerSelection = {};
  bool _mistakeThisPattern = false;

  /// Rounds survived without a perfect streak being required.
  int get currentPattern => _current;

  bool get isFinished => _current >= patterns.length;

  Set<int> get currentPatternCells => _current < patterns.length ? patterns[_current] : {};

  Set<int> get playerSelection => _playerSelection;

  bool get madeMistake => _mistakeThisPattern;

  /// Cells selected so far.
  int get selectedCount => _playerSelection.length;

  /// Registers a tap. Returns the resulting state transition.
  MemoryTapResult tap(int cellIndex) {
    if (isFinished) return MemoryTapResult.ignored;
    final target = patterns[_current];
    if (!target.contains(cellIndex)) {
      _mistakeThisPattern = true;
      return MemoryTapResult.miss;
    }
    _playerSelection.add(cellIndex);
    if (_playerSelection.length == target.length) {
      _current++;
      final perfect = !_mistakeThisPattern;
      _playerSelection = {};
      _mistakeThisPattern = false;
      return _current >= patterns.length
          ? MemoryTapResult.completed
          : MemoryTapResult.patternComplete(perfect);
    }
    return MemoryTapResult.hit;
  }

  /// Number of patterns a level deals. Exposed statically so the save/resume
  /// layer can reason about a persisted payload without rebuilding a board.
  static int patternCountForLevel(int level) => (2 + level ~/ 4).clamp(2, 8);

  static int _sizeForLevel(int level) {
    if (level <= 8) return 3;
    if (level <= 24) return 4;
    return 5;
  }

  /// Jumps to a stored pattern index without reshuffling — used by the
  /// save/resume layer so a reopened level continues its original deal.
  void restoreToPattern(int index) {
    _current = index.clamp(0, patterns.length);
    _playerSelection = {};
    _mistakeThisPattern = false;
  }
}

enum MemoryTapKind { hit, miss, patternComplete, completed, ignored }

/// Outcome of one tap during recall.
class MemoryTapResult {
  const MemoryTapResult._(this.kind, {this.wasPerfect = false});

  final MemoryTapKind kind;

  /// Set when [kind] is [MemoryTapKind.patternComplete].
  final bool wasPerfect;

  static const MemoryTapResult hit =
      MemoryTapResult._(MemoryTapKind.hit);
  static const MemoryTapResult miss =
      MemoryTapResult._(MemoryTapKind.miss);
  static const MemoryTapResult completed =
      MemoryTapResult._(MemoryTapKind.completed);
  static const MemoryTapResult ignored =
      MemoryTapResult._(MemoryTapKind.ignored);

  static MemoryTapResult patternComplete(bool perfect) =>
      MemoryTapResult._(MemoryTapKind.patternComplete, wasPerfect: perfect);
}
