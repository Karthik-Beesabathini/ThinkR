import 'dart:math';

/// Deterministic sliding-tile puzzle (15-puzzle family).
///
/// Shuffles by applying random valid moves from the solved state, which
/// guarantees solvability. Parity check is kept as an extra safety net.
class ShiftPuzzle {
  ShiftPuzzle({required int level, required int seed})
      : size = _sizeForLevel(level) {
    final rng = Random(seed);
    // Solved state: 1..n*n-1, 0 = empty.
    tiles = [for (var i = 1; i < size * size; i++) i, 0];
    final shuffles = _shuffleCount(level);
    var blank = tiles.length - 1;
    var previousBlank = -1;
    for (var i = 0; i < shuffles; i++) {
      final neighbors = _neighborsOf(blank).toList()
        ..remove(previousBlank)
        ..shuffle(rng);
      final target = neighbors.first;
      tiles[blank] = tiles[target];
      tiles[target] = 0;
      previousBlank = blank;
      blank = target;
    }
  }

  final int size;
  late final List<int> tiles;

  /// Shuffle length ramps with the level: early levels teach the mechanic
  /// with short scrambles, later levels are genuinely mixed.
  static int _shuffleCount(int level) {
    if (level <= 10) return 12 + level * 3;
    if (level <= 30) return 50 + (level - 10) * 7;
    return 220 + (level - 30) * 12;
  }

  static int _sizeForLevel(int level) {
    if (level <= 10) return 3;
    if (level <= 30) return 4;
    return 5;
  }

  bool isSolved(List<int> board) {
    for (var i = 0; i < board.length - 1; i++) {
      if (board[i] != i + 1) return false;
    }
    return board.last == 0;
  }

  int indexOfBlank(List<int> board) => board.indexOf(0);

  bool canSlide(List<int> board, int index) =>
      _neighborsOf(board.indexOf(0)).contains(index);

  Iterable<int> _neighborsOf(int blankIndex) sync* {
    final r = blankIndex ~/ size;
    final c = blankIndex % size;
    if (r > 0) yield blankIndex - size;
    if (r < size - 1) yield blankIndex + size;
    if (c > 0) yield blankIndex - 1;
    if (c < size - 1) yield blankIndex + 1;
  }

  List<int> slide(List<int> board, int index) {
    final next = [...board];
    final blank = next.indexOf(0);
    next[blank] = next[index];
    next[index] = 0;
    return next;
  }

  int manhattanOf(List<int> board) {
    var distance = 0;
    for (var i = 0; i < board.length; i++) {
      final tile = board[i];
      if (tile == 0) continue;
      final goalIndex = tile - 1;
      final r = i ~/ size, c = i % size;
      final gr = goalIndex ~/ size, gc = goalIndex % size;
      distance += (r - gr).abs() + (c - gc).abs();
    }
    return distance;
  }

  /// Restores a previously saved board (save/resume support) — the exact
  /// tile arrangement comes back, never reshuffled.
  ShiftPuzzle.fromState({required this.size, required this.tiles});

  /// Serialized in-progress state for the save/resume layer.
  Map<String, dynamic> serialize() =>
      {'size': size, 'tiles': tiles.toList()};

  /// Rebuilds a board from [serialize] output. Returns null when the
  /// payload is malformed (the level then starts fresh instead).
  static ShiftPuzzle? fromSerialized(Map<String, dynamic> json) {
    final size = (json['size'] as num?)?.toInt();
    final rawTiles = json['tiles'];
    if (size == null || size < 2 || rawTiles is! List) return null;
    final tiles = rawTiles.map((tile) => (tile as num).toInt()).toList();
    if (tiles.length != size * size) return null;
    return ShiftPuzzle.fromState(size: size, tiles: tiles);
  }

  /// Suggests the next move for the hint system.
  ///
  /// Strategy, in order:
  ///  1. 3×3 boards are small enough to search exhaustively — the hint is
  ///     then a move from the *optimal* solution.
  ///  2. Larger boards: play a move that strictly decreases the Manhattan
  ///     distance.
  ///  3. If every move increases the distance (a local minimum), run a
  ///     bounded breadth-first search for the shortest escape to a state
  ///     with a lower distance.
  ///  4. Fall back to the move that increases the distance the least,
  ///     avoiding an immediate reversal of the previous hint when the
  ///     caller supplies [avoidIndex].
  ///
  /// Every phase is node-budgeted, so this never meaningfully blocks the
  /// UI thread and never reveals more than one move.
  int? solveNextMoveIndex(List<int> board, {int? avoidIndex}) {
    if (isSolved(board)) return null;

    // 1. Exhaustive (and optimal) for the smallest boards.
    if (board.length == 9) {
      final path = _bfsToGoal(board, nodeBudget: 220000);
      if (path != null && path.isNotEmpty) return path.first;
    }

    var candidates = _neighborsOf(board.indexOf(0)).toList()..sort();
    if (candidates.length > 1 &&
        avoidIndex != null &&
        candidates.contains(avoidIndex)) {
      candidates = [...candidates.where((c) => c != avoidIndex), avoidIndex];
    }

    final h = manhattanOf(board);

    // 2. Strictly decreasing move.
    int? greedy;
    var greedyChildH = h;
    for (final candidate in candidates) {
      final childH = manhattanOf(slide(board, candidate));
      if (childH < greedyChildH) {
        greedyChildH = childH;
        greedy = candidate;
      }
    }
    if (greedy != null) return greedy;

    // 3. Local minimum: bounded BFS to a lower-distance state.
    final escape =
        _escapeMove(board, nodeBudget: 60000, avoidIndex: avoidIndex);
    if (escape != null) return escape;

    // 4. Bounded fallback: least harm.
    var best = candidates.first;
    var bestH = 1 << 30;
    for (final candidate in candidates) {
      final childH = manhattanOf(slide(board, candidate));
      if (childH < bestH) {
        bestH = childH;
        best = candidate;
      }
    }
    return best;
  }

  /// Breadth-first search for the shortest full solution. Guaranteed on
  /// 3×3 (181,440 states); budget-bounded on larger boards.
  List<int>? _bfsToGoal(List<int> board, {required int nodeBudget}) {
    var nodes = 0;
    final rootKey = board.join(',');
    final parents = <String, String?>{rootKey: null};
    final moveFromParent = <String, int>{};
    final boards = <String, List<int>>{rootKey: board};
    final queue = <String>[rootKey];

    while (queue.isNotEmpty && nodes < nodeBudget) {
      final key = queue.removeAt(0);
      nodes++;
      final current = boards[key]!;
      if (manhattanOf(current) == 0) {
        final path = <int>[];
        var k = key;
        while (moveFromParent[k] != null) {
          path.add(moveFromParent[k]!);
          k = parents[k]!;
        }
        return path.reversed.toList();
      }
      final blank = current.indexOf(0);
      for (final next in _neighborsOf(blank)) {
        final child = slide(current, next);
        final childKey = child.join(',');
        if (parents.containsKey(childKey)) continue;
        parents[childKey] = key;
        moveFromParent[childKey] = next;
        boards[childKey] = child;
        queue.add(childKey);
      }
    }
    return null;
  }

  /// Breadth-first search for the shortest move sequence that reaches a
  /// state with a strictly lower Manhattan distance than [board]'s.
  /// Explores at most [nodeBudget] states. Never hangs, never throws.
  int? _escapeMove(
    List<int> board, {
    required int nodeBudget,
    required int? avoidIndex,
  }) {
    final targetH = manhattanOf(board);
    var nodes = 0;
    final queue = <(List<int>, List<int>)>[(board, const <int>[])];
    final seen = {board.join(',')};
    while (queue.isNotEmpty && nodes < nodeBudget) {
      final (current, path) = queue.removeAt(0);
      nodes++;
      for (final next in _neighborsOf(current.indexOf(0))) {
        if (path.isEmpty && next == avoidIndex) continue;
        final child = slide(current, next);
        final key = child.join(',');
        if (seen.contains(key)) continue;
        seen.add(key);
        final childPath = <int>[...path, next];
        if (manhattanOf(child) < targetH) return childPath.first;
        queue.add((child, childPath));
      }
    }
    return null;
  }

  /// Public wrapper for the bounded path search — used by the board for
  /// perfect-solve tracking and by tests.
  List<int>? pathWithinDepth(
    List<int> board, {
    int depthCap = 60,
    required int nodeBudget,
  }) =>
      _pathWithinDepth(board, depthCap: depthCap, nodeBudget: nodeBudget);

  /// Finds *a* solution path of at most [depthCap] moves, exploring no
  /// more than [nodeBudget] states. Returns null when the budget or the
  /// depth cap is exhausted — never throws, never hangs.
  List<int>? _pathWithinDepth(
    List<int> board, {
    required int depthCap,
    required int nodeBudget,
  }) {
    var nodes = 0;
    List<int>? dfs(List<int> nodeBoard, int g, Set<String> seen) {
      if (nodes++ > nodeBudget) return null;
      if (manhattanOf(nodeBoard) == 0) return const <int>[];
      if (g >= depthCap) return null;
      final blank = nodeBoard.indexOf(0);
      for (final next in _neighborsOf(blank)) {
        final child = slide(nodeBoard, next);
        final key = child.join(',');
        if (seen.contains(key)) continue;
        seen.add(key);
        final tail = dfs(child, g + 1, seen);
        if (tail != null) return <int>[next, ...tail];
      }
      return null;
    }

    return dfs(board, 0, {board.join(',')});
  }

}
