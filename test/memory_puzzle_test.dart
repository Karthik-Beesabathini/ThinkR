import 'package:flutter_test/flutter_test.dart';
import 'package:thinkr/games/memory/memory_puzzle.dart';

void main() {
  test('level 1 is a 3x3 board with deterministic patterns', () {
    final a = MemoryPuzzle(level: 1, seed: 11);
    final b = MemoryPuzzle(level: 1, seed: 11);
    expect(a.size, 3);
    expect(a.patterns, b.patterns);
  });

  test('correct taps complete a pattern, wrong taps miss', () {
    final puzzle = MemoryPuzzle(level: 2, seed: 3);
    final target = puzzle.currentPatternCells;

    // A wrong tap registers a miss.
    final wrongIndex = [
      for (var i = 0; i < puzzle.size * puzzle.size; i++)
        if (!target.contains(i)) i,
    ].first;
    expect(puzzle.tap(wrongIndex).kind, MemoryTapKind.miss);

    // Hitting every cell of the pattern completes it.
    final fresh = MemoryPuzzle(level: 2, seed: 3);
    for (final cell in fresh.currentPatternCells) {
      final result = fresh.tap(cell);
      expect(result.kind, isNot(MemoryTapKind.miss));
    }
    expect(fresh.currentPattern, 1);
  });

  test('finishing every pattern reports completed', () {
    final puzzle = MemoryPuzzle(level: 1, seed: 8);
    MemoryTapResult result = MemoryTapResult.ignored;
    while (!puzzle.isFinished) {
      for (final cell in puzzle.currentPatternCells) {
        result = puzzle.tap(cell);
      }
    }
    expect(result.kind, MemoryTapKind.completed);
  });

  test('difficulty scales without exploding', () {
    final early = MemoryPuzzle(level: 1, seed: 1);
    final late = MemoryPuzzle(level: 40, seed: 1);
    expect(late.size, greaterThanOrEqualTo(early.size));
    expect(late.patterns.first.length, lessThanOrEqualTo(late.size * late.size));
  });
}
