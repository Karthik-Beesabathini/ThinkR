import 'package:flutter_test/flutter_test.dart';
import 'package:thinkr/games/switchyard_escape/engine/switchyard_engine.dart';
import 'package:thinkr/games/switchyard_escape/levels/level_repository.dart';

/// Top-down authoring helper for test-only levels.
LevelData level({
  int rows = 3,
  int cols = 8,
  required List<String> glyphs,
  required List<TrainSpec> trains,
  required List<({int r, int c, Dir out})> exits,
  List<SwitchDef> switches = const [],
}) =>
    LevelData(
      id: 0,
      rows: rows,
      cols: cols,
      tracks: [
        for (final g in glyphs) [for (final ch in g.split('')) parseTrack(ch)],
      ],
      trains: trains,
      exits: exits,
      switches: switches,
      difficulty: 1,
      idea: 'test',
    );

/// A straight corridor across row 1 with a right exit at the far edge.
LevelData corridor({
  required List<TrainSpec> trains,
  int rows = 3,
  int cols = 8,
}) =>
    level(
      rows: rows,
      cols: cols,
      glyphs: ['·' * cols, '═' * cols, '·' * cols],
      trains: trains,
      exits: [(r: 1, c: cols - 1, out: Dir.right)],
    );

void main() {
  group('glyph parsing', () {
    test('empty cells are not track', () {
      expect(parseTrack('·'), isNull);
      expect(parseTrack(' '), isNull);
    });

    test('unknown glyphs fail loudly instead of becoming phantom track', () {
      expect(() => parseTrack('t'), throwsFormatException);
      expect(() => parseTrack('x'), throwsFormatException);
    });
  });

  group('movement', () {
    test('a single tap sends a train out and solves the board', () {
      final engine = SwitchYardEngine(corridor(
        trains: [TrainSpec(r: 1, c: 1, facing: Dir.right, length: 2, tone: 0)],
      ));
      final result = engine.dispatch(0);
      expect(result.outcome, DispatchOutcome.exited);
      expect(engine.trains[0].escaped, isTrue);
      expect(engine.solved, isTrue);
    });

    test('a train moves as one rigid body, not stretched across its route',
        () {
      // Track only reaches column 4 (a dead end), so the train cannot exit
      // and must end up contiguous.
      final engine = SwitchYardEngine(level(
        rows: 3,
        cols: 8,
        glyphs: ['········', '═════···', '········'],
        trains: [
          TrainSpec(r: 1, c: 2, facing: Dir.right, length: 3, tone: 0),
        ],
        exits: const [],
      ));
      final result = engine.dispatch(0);
      expect(result.outcome, DispatchOutcome.moved);

      final segments = engine.trains[0].segments;
      expect(segments, [
        (r: 1, c: 4),
        (r: 1, c: 3),
        (r: 1, c: 2),
      ]);
      // Contiguity: every neighbouring pair is one grid step apart.
      for (var i = 0; i + 1 < segments.length; i++) {
        final a = segments[i];
        final b = segments[i + 1];
        expect((a.r - b.r).abs() + (a.c - b.c).abs(), 1);
      }
    });

    test('a route never continues onto empty ground', () {
      final engine = SwitchYardEngine(level(
        rows: 3,
        cols: 8,
        glyphs: ['········', '═════···', '········'],
        trains: [TrainSpec(r: 1, c: 1, facing: Dir.right, length: 2, tone: 0)],
        exits: const [],
      ));
      final route = engine.routeFor(engine.trains[0]);
      expect(route.contains((r: 1, c: 5)), isFalse);
      expect(route.last, (r: 1, c: 4));
    });

    test('a curve steers the train onto the connecting track', () {
      final engine = SwitchYardEngine(level(
        rows: 4,
        cols: 4,
        glyphs: ['·║··', '·║··', '·└══', '····'],
        trains: [TrainSpec(r: 1, c: 1, facing: Dir.down, length: 2, tone: 0)],
        exits: [(r: 2, c: 3, out: Dir.right)],
      ));
      final result = engine.dispatch(0);
      expect(result.outcome, DispatchOutcome.exited);
      expect(result.path, [(r: 2, c: 1), (r: 2, c: 2), (r: 2, c: 3)]);
    });
  });

  group('collisions', () {
    test('a train directly ahead blocks instead of punishing', () {
      final engine = SwitchYardEngine(corridor(
        trains: [
          TrainSpec(r: 1, c: 1, facing: Dir.right, length: 2, tone: 0),
          TrainSpec(r: 1, c: 2, facing: Dir.right, length: 1, tone: 1),
        ],
      ));
      final before = engine.stateKey();
      final result = engine.dispatch(0);

      expect(result.outcome, DispatchOutcome.blocked);
      expect(result.blockedBy, 1);
      expect(engine.stateKey(), before, reason: 'blocked must not move');
      expect(engine.solved, isFalse);
    });

    test('dispatching onto a train further down the line crashes', () {
      final engine = SwitchYardEngine(corridor(
        trains: [
          TrainSpec(r: 1, c: 1, facing: Dir.right, length: 1, tone: 0),
          TrainSpec(r: 1, c: 4, facing: Dir.right, length: 1, tone: 1),
        ],
      ));
      final before = engine.stateKey();
      final result = engine.dispatch(0);

      expect(result.outcome, DispatchOutcome.crash);
      expect(result.crashCell, (r: 1, c: 4));
      expect(engine.stateKey(), before, reason: 'a crash must not move');
    });

    test('order matters: clear the blocker first, then the line is free', () {
      final levels = buildSwitchYardLevels();
      final engine = SwitchYardEngine(levels.firstWhere((l) => l.id == 3));

      expect(engine.dispatch(0).outcome, DispatchOutcome.blocked);
      expect(engine.dispatch(1).outcome, DispatchOutcome.exited);
      expect(engine.dispatch(0).outcome, DispatchOutcome.exited);
      expect(engine.solved, isTrue);
    });
  });

  group('switches', () {
    LevelData switchLine() => level(
          rows: 3,
          cols: 6,
          glyphs: ['······', '══════', '······'],
          trains: [TrainSpec(r: 1, c: 1, facing: Dir.right, length: 2, tone: 0)],
          exits: [(r: 1, c: 5, out: Dir.right)],
          switches: [
            SwitchDef(
              row: 1,
              col: 3,
              from: Dir.right,
              straight: Dir.right,
              branch: Dir.down,
            ),
          ],
        );

    test('the resting route goes straight to the exit', () {
      final engine = SwitchYardEngine(switchLine());
      expect(engine.switchStateB(0), isFalse);
      expect(engine.dispatch(0).outcome, DispatchOutcome.exited);
    });

    test('toggling the switch diverts the train', () {
      final engine = SwitchYardEngine(switchLine());
      expect(engine.toggleSwitch(0), isTrue);
      expect(engine.switchStateB(0), isTrue);

      final result = engine.dispatch(0);
      expect(result.outcome, DispatchOutcome.moved);
      expect(engine.trains[0].head, (r: 1, c: 3));
    });
  });

  group('undo and persistence', () {
    test('undo restores the exact previous position', () {
      final engine = SwitchYardEngine(corridor(
        trains: [TrainSpec(r: 1, c: 1, facing: Dir.right, length: 2, tone: 0)],
      ));
      final before = engine.stateKey();
      engine.dispatch(0);
      expect(engine.stateKey(), isNot(before));

      expect(engine.undo(), isTrue);
      expect(engine.stateKey(), before);
      expect(engine.undo(), isFalse);
    });

    test('undo also reverses a switch toggle', () {
      final engine = SwitchYardEngine(level(
        rows: 3,
        cols: 3,
        glyphs: ['···', '═══', '···'],
        trains: [TrainSpec(r: 1, c: 0, facing: Dir.right, length: 2, tone: 0)],
        exits: const [],
        switches: [
          SwitchDef(
            row: 1,
            col: 1,
            from: Dir.right,
            straight: Dir.right,
            branch: Dir.down,
          ),
        ],
      ));
      engine.toggleSwitch(0);
      engine.undo();
      expect(engine.switchStateB(0), isFalse);
    });

    test('serialize/restore round-trips the live state', () {
      final engine = SwitchYardEngine(level(
        rows: 3,
        cols: 6,
        glyphs: ['······', '══════', '······'],
        trains: [TrainSpec(r: 1, c: 1, facing: Dir.right, length: 2, tone: 0)],
        exits: [(r: 1, c: 5, out: Dir.right)],
        switches: [
          SwitchDef(
            row: 1,
            col: 3,
            from: Dir.right,
            straight: Dir.right,
            branch: Dir.down,
          ),
        ],
      ));
      engine.toggleSwitch(0);
      engine.dispatch(0);
      final saved = engine.serialize();

      final restored = SwitchYardEngine(engine.level)..restore(saved);
      expect(restored.stateKey(), engine.stateKey());
    });

    test('a corrupt save is ignored and the level starts fresh', () {
      final engine = SwitchYardEngine(corridor(
        trains: [TrainSpec(r: 1, c: 1, facing: Dir.right, length: 2, tone: 0)],
      ));
      final before = engine.stateKey();
      engine.restore({'trains': 'not-a-list'});
      expect(engine.stateKey(), before);
    });
  });

  group('level repository', () {
    test('every authored level loads, is well-formed, and is solvable', () {
      final levels = buildSwitchYardLevels();
      expect(levels, isNotEmpty);

      for (final levelData in levels) {
        expect(levelData.rows, greaterThan(0), reason: 'level ${levelData.id}');
        expect(levelData.cols, greaterThan(0), reason: 'level ${levelData.id}');
        expect(
          levelData.tracks.length,
          levelData.rows,
          reason: 'level ${levelData.id} track row count',
        );
        for (final row in levelData.tracks) {
          expect(
            row.length,
            levelData.cols,
            reason: 'level ${levelData.id} track column count',
          );
        }
        expect(
          levelData.trains,
          isNotEmpty,
          reason: 'level ${levelData.id} has no trains',
        );
        for (final train in levelData.trains) {
          expect(
            train.length,
            greaterThan(0),
            reason: 'level ${levelData.id} train length',
          );
        }

        // BFS over dispatches and switch toggles proves escapability.
        final solved = _canSolve(levelData);
        expect(
          solved,
          isTrue,
          reason: 'level ${levelData.id} (${levelData.idea}) is unsolvable',
        );
      }
    });

    test('level ids are unique and contiguous from 1', () {
      final levels = buildSwitchYardLevels();
      final ids = levels.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate ids');
      expect(ids, List.generate(ids.length, (i) => i + 1));
    });
  });
}

/// Breadth-first search across "dispatch a train" and "toggle a switch",
/// treating blocked moves as no-ops-in-place so it never churns forever.
bool _canSolve(LevelData levelData, {int maxStates = 20000}) {
  final start = SwitchYardEngine(levelData);
  if (start.solved) return true;

  final queue = <SwitchYardEngine>[start];
  final visited = <String>{start.stateKey()};
  var explored = 0;

  while (queue.isNotEmpty && explored < maxStates) {
    final state = queue.removeAt(0);
    explored++;

    for (var trainId = 0; trainId < state.trains.length; trainId++) {
      final next = state.clone();
      final result = next.dispatch(trainId);
      if (result.outcome == DispatchOutcome.blocked ||
          result.outcome == DispatchOutcome.crash) {
        continue;
      }
      if (!visited.add(next.stateKey())) continue;
      if (next.solved) return true;
      queue.add(next);
    }

    for (var s = 0; s < state.switchCount; s++) {
      final next = state.clone()..toggleSwitch(s);
      if (!visited.add(next.stateKey())) continue;
      queue.add(next);
    }
  }
  return false;
}
