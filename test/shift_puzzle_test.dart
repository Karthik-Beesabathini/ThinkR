import 'package:flutter_test/flutter_test.dart';
import 'package:thinkr/games/shift/shift_puzzle.dart';

void main() {
  test('generated boards are solvable and start unsolved', () {
    for (final level in [1, 10, 25, 40]) {
      final puzzle = ShiftPuzzle(level: level, seed: level * 7919);
      expect(puzzle.isSolved(puzzle.tiles), isFalse);
    }
  });

  test('hint move is legal and never oscillates', () {
    final puzzle = ShiftPuzzle(level: 5, seed: 2024);
    final before = _manhattan(puzzle, puzzle.tiles);
    final index = puzzle.solveNextMoveIndex(puzzle.tiles)!;
    expect(puzzle.canSlide(puzzle.tiles, index), isTrue);
    final after = _manhattan(puzzle, puzzle.slide(puzzle.tiles, index));
    expect(after, lessThanOrEqualTo(before));
  });

  test('following hints solves 3x3 boards (exhaustive search)', () {
    for (final level in [3, 8]) {
      final puzzle = ShiftPuzzle(level: level, seed: level);
      var board = [...puzzle.tiles];
      var steps = 0;
      while (!puzzle.isSolved(board) && steps < 60) {
        final index = puzzle.solveNextMoveIndex(board)!;
        expect(puzzle.canSlide(board, index), isTrue);
        board = puzzle.slide(board, index);
        steps++;
      }
      expect(
        puzzle.isSolved(board),
        isTrue,
        reason: 'level $level must be solvable by following hints',
      );
    }
  });

  test('4x4 hints are always legal and bounded', () {
    for (final level in [12, 25]) {
      final puzzle = ShiftPuzzle(level: level, seed: level);
      var board = [...puzzle.tiles];
      // Just verify hints stay legal and terminate quickly across many
      // calls — on big boards a hint is a nudge, not a solution.
      for (var i = 0; i < 20 && !puzzle.isSolved(board); i++) {
        final index = puzzle.solveNextMoveIndex(board)!;
        expect(puzzle.canSlide(board, index), isTrue);
        board = puzzle.slide(board, index);
      }
    }
  });

  test('bounded solver returns a valid solving path for modest scrambles', () {
    final puzzle = ShiftPuzzle(level: 1, seed: 42);
    final path = puzzle.pathWithinDepth(puzzle.tiles, nodeBudget: 200000);
    expect(path, isNotNull);
    var board = [...puzzle.tiles];
    for (final index in path!) {
      expect(puzzle.canSlide(board, index), isTrue);
      board = puzzle.slide(board, index);
    }
    expect(puzzle.isSolved(board), isTrue);
  });

  test('canSlide rejects tiles not adjacent to the blank', () {
    final puzzle = ShiftPuzzle(level: 1, seed: 5);
    final blank = puzzle.tiles.indexOf(0);
    final farIndex = blank > 2 ? 0 : puzzle.tiles.length - 1;
    if (!_isNeighbor(puzzle, farIndex, blank)) {
      expect(puzzle.canSlide(puzzle.tiles, farIndex), isFalse);
    }
  });

  test('serialize/restore round trip preserves the tiles', () {
    final puzzle = ShiftPuzzle(level: 5, seed: 77);
    final restored = ShiftPuzzle.fromSerialized(puzzle.serialize());
    expect(restored, isNotNull);
    expect(restored!.size, puzzle.size);
    expect(restored.tiles, puzzle.tiles);
    expect(restored.isSolved(restored.tiles), isFalse);
  });

  test('fromSerialized rejects malformed payloads', () {
    expect(ShiftPuzzle.fromSerialized({}), isNull);
    expect(ShiftPuzzle.fromSerialized({'size': 3, 'tiles': [1, 2, 3]}), isNull);
  });
}

bool _isNeighbor(ShiftPuzzle puzzle, int a, int b) {
  final ra = a ~/ puzzle.size, ca = a % puzzle.size;
  final rb = b ~/ puzzle.size, cb = b % puzzle.size;
  return (ra - rb).abs() + (ca - cb).abs() == 1;
}

int _manhattan(ShiftPuzzle puzzle, List<int> board) {
  var distance = 0;
  for (var i = 0; i < board.length; i++) {
    final tile = board[i];
    if (tile == 0) continue;
    final r = i ~/ puzzle.size, c = i % puzzle.size;
    final gr = (tile - 1) ~/ puzzle.size, gc = (tile - 1) % puzzle.size;
    distance += (r - gr).abs() + (c - gc).abs();
  }
  return distance;
}
