import 'package:flutter_test/flutter_test.dart';
import 'package:thinkr/games/lights/lights_puzzle.dart';

void main() {
  test('levels are deterministic for the same seed', () {
    final a = LightsPuzzle(level: 5, seed: 1234);
    final b = LightsPuzzle(level: 5, seed: 1234);
    expect(a.size, b.size);
    for (var r = 0; r < a.size; r++) {
      expect(a.lights[r], b.lights[r]);
    }
  });

  test('press toggles the cross around the pressed cell', () {
    final puzzle = LightsPuzzle(level: 1, seed: 7);
    final before =
        List.generate(3, (r) => List.generate(3, (c) => puzzle.lights[r][c]));
    puzzle.press((r: 0, c: 0));
    // Corners toggle 3 cells, edges 4, centers 5.
    expect(puzzle.lights[0][0], !before[0][0]);
    expect(puzzle.lights[0][1], !before[0][1]);
    expect(puzzle.lights[1][0], !before[1][0]);
    // (1,1) is not touched by pressing (0,0).
    expect(puzzle.lights[1][1], before[1][1]);
  });

  test('playing the generating presses returns to solved state', () {
    final puzzle = LightsPuzzle(level: 9, seed: 99);
    expect(puzzle.isSolved, isFalse);
    for (final cell in puzzle.generatingPresses) {
      puzzle.press(cell);
    }
    expect(puzzle.isSolved, isTrue);
    expect(puzzle.solutionParity, isEmpty);
  });

  test('hint cell is always part of the remaining solution', () {
    final puzzle = LightsPuzzle(level: 14, seed: 42);
    // Apply the hint repeatedly until solved — the parity hint must
    // always lead toward the solution.
    var steps = 0;
    while (!puzzle.isSolved && steps < 100) {
      expect(puzzle.hasHint, isTrue);
      puzzle.press(puzzle.hintCell());
      steps++;
    }
    expect(puzzle.isSolved, isTrue);
  });

  test('board size grows with level', () {
    expect(LightsPuzzle(level: 1, seed: 1).size, 3);
    expect(LightsPuzzle(level: 13, seed: 1).size, 4);
    expect(LightsPuzzle(level: 33, seed: 1).size, 5);
  });

  test('serialize/restore round trip preserves the exact board', () {
    final puzzle = LightsPuzzle(level: 20, seed: 123);
    // Make a few (hint-guided) presses so the state diverges from fresh.
    for (var i = 0; i < 3; i++) {
      puzzle.press(puzzle.hintCell());
    }
    expect(puzzle.isSolved, isFalse);

    final restored = LightsPuzzle.fromSerialized(puzzle.serialize());
    expect(restored, isNotNull);
    expect(restored!.size, puzzle.size);
    expect(restored.lights, equals(puzzle.lights));
    expect(restored.solutionParity, equals(puzzle.solutionParity));
    expect(restored.generatingPresses, equals(puzzle.generatingPresses));
    expect(restored.isSolved, puzzle.isSolved);
    expect(restored.optimalMoves, puzzle.optimalMoves);

    // Hints must still be exact after a restore.
    expect(restored.hasHint, puzzle.hasHint);
    if (restored.hasHint) {
      final hint = restored.hintCell();
      expect(puzzle.solutionParity, contains(hint));
    }
  });

  test('fromSerialized rejects malformed payloads', () {
    expect(LightsPuzzle.fromSerialized({}), isNull);
    expect(LightsPuzzle.fromSerialized({'size': 3}), isNull);
    expect(
      LightsPuzzle.fromSerialized(const {
        'size': 3,
        'lights': [
          [1, 0],
          [0, 0],
        ],
        'parity': <String>[],
        'generated': <String>[],
      }),
      isNull,
    );
  });
}
