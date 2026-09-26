import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkr/games/memory/memory_controller.dart';
import 'package:thinkr/games/memory/memory_puzzle.dart';

void main() {
  const level = 1;
  const seed = 99;

  // Level 1: two patterns of three cells on a 3x3 board.
  final puzzle = MemoryPuzzle(level: level, seed: seed);
  final correct = puzzle.patterns[0].first;
  final wrong = [
    for (var i = 0; i < 9; i++) i,
  ].firstWhere((cell) => !puzzle.patterns[0].contains(cell));

  MemoryGameController buildController({
    Map<String, dynamic>? saved,
    bool duel = false,
    List<Map<String, dynamic>>? restarts,
  }) {
    return MemoryGameController(
      level: level,
      seed: seed,
      duel: duel,
      onMove: () {},
      onInvalidMove: (_) {},
      onSolved: (summary, optimal) {},
      onRestart: () => restarts?.add(const {}),
      saved: saved,
    );
  }

  test('correct tap stays found; wrong tap locks, counts, prompts', () {
    fakeAsync((async) {
      final controller = buildController(restarts: []);
      // Show phase → recall.
      async.elapse(const Duration(milliseconds: 1900));

      expect(controller.interactive, isTrue);
      controller.tap(correct);
      expect(controller.foundCells, contains(correct));
      expect(controller.mistakes, 0);
      // Input locked while the success feedback plays.
      expect(controller.interactive, isFalse);
      async.elapse(const Duration(milliseconds: 200));
      expect(controller.interactive, isTrue);

      controller.tap(wrong);
      expect(controller.mistakes, 1);
      expect(controller.errorCell, wrong);
      expect(controller.interactive, isFalse);

      // The prompt appears after the error feedback window.
      expect(controller.wrongPromptVisible, isFalse);
      async.elapse(const Duration(milliseconds: 700));
      expect(controller.wrongPromptVisible, isTrue);

      // Rapid tapping during feedback cannot corrupt the state.
      controller.tap(correct);
      controller.tap(wrong);
      expect(controller.mistakes, 1);
      expect(controller.errorCell, wrong);
    });
  });

  test('try again re-shows the same pattern and keeps the mistake', () {
    fakeAsync((async) {
      final controller = buildController(restarts: []);
      async.elapse(const Duration(milliseconds: 1900));
      controller.tap(wrong);
      async.elapse(const Duration(milliseconds: 700));

      controller.tryAgain();
      expect(controller.wrongPromptVisible, isFalse);
      expect(controller.errorCell, isNull);
      expect(controller.mistakes, 1);
      // A short "between" beat, then the pattern is re-shown.
      expect(controller.phase, MemoryPhase.between);
      async.elapse(const Duration(milliseconds: 800));
      expect(controller.phase, MemoryPhase.showing);
      expect(controller.puzzle.currentPattern, 0);
    });
  });

  test('replay restarts the level and notifies the shell', () {
    fakeAsync((async) {
      final restarts = <Map<String, dynamic>>[];
      final controller = buildController(restarts: restarts);
      async.elapse(const Duration(milliseconds: 1900));
      controller.tap(correct);
      // The success feedback holds a short input lock.
      async.elapse(const Duration(milliseconds: 150));
      controller.tap(wrong);
      async.elapse(const Duration(milliseconds: 700));

      controller.replayLevel();
      expect(controller.mistakes, 0);
      expect(controller.foundCells, isEmpty);
      expect(controller.puzzle.currentPattern, 0);
      expect(controller.phase, MemoryPhase.showing);
      expect(restarts.length, 1);
    });
  });

  test('serialize/restore round trip preserves the exact progress', () {
    fakeAsync((async) {
      final controller = buildController();
      async.elapse(const Duration(milliseconds: 1900));
      controller.tap(correct); // 1 of 3 cells found

      final saved = controller.serializeProgress();
      expect(saved, isNotNull);
      expect(saved!['pattern'], 0);
      expect(saved['phase'], 'recall');
      expect(saved['found'], [correct]);

      final restored = buildController(saved: saved);
      expect(restored.phase, MemoryPhase.recall);
      expect(restored.foundCells, {correct});
      expect(restored.mistakes, 0);
      expect(restored.puzzle.currentPattern, 0);
      // Mid-recall restore is interactive right away.
      expect(restored.interactive, isTrue);
    });
  });

  test('stale or corrupt saves start the level fresh', () {
    fakeAsync((async) {
      final stale = buildController(
        saved: {'pattern': 99, 'phase': 'recall', 'found': [1]},
      );
      expect(stale.puzzle.currentPattern, 0);
      expect(stale.foundCells, isEmpty);
      expect(stale.phase, MemoryPhase.showing);

      final empty = buildController(
        saved: {'pattern': 0, 'phase': 'recall', 'found': []},
      );
      expect(empty.phase, MemoryPhase.showing);
    });
  });

  test('completing every pattern reports solved with optimal moves', () {
    fakeAsync((async) {
      int? reportedOptimal;
      final controller = MemoryGameController(
        level: level,
        seed: seed,
        duel: false,
        onMove: () {},
        onInvalidMove: (_) {},
        onSolved: (summary, optimal) => reportedOptimal = optimal,
        onRestart: () {},
      );
      async.elapse(const Duration(milliseconds: 1900));
      for (final pattern in puzzle.patterns) {
        for (final cell in pattern.toList()) {
          async.elapse(const Duration(milliseconds: 150));
          controller.tap(cell);
        }
        // Pattern complete → short "between" beat → next pattern or done.
        async.elapse(const Duration(milliseconds: 800));
        async.elapse(const Duration(milliseconds: 1900));
      }
      expect(controller.phase, MemoryPhase.done);
      expect(reportedOptimal, controller.puzzle.patternCount * controller.puzzle.cellsPerPattern);
    });
  });
}
