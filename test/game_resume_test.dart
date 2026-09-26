import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinkr/app/app.dart';
import 'package:thinkr/core/storage/local_storage.dart';
import 'package:thinkr/games/game_catalog.dart';
import 'package:thinkr/games/lights/lights_tile.dart';
import 'package:thinkr/games/memory/memory_puzzle.dart';

/// End-to-end save/resume, reset and lifecycle coverage for the shared
/// gameplay shell (Memory + Lights):
///
/// * leaving mid-level persists the exact board,
/// * reopening restores it without reshuffling,
/// * Reset throws the attempt away cleanly,
/// * completing a level clears its unfinished save and unlocks the next,
/// * rapid tapping never corrupts state,
/// * no "setState() or markNeedsBuild() called during build" anywhere.
void main() {
  Future<LocalStorage> launch(WidgetTester tester) async {
    // Skip the first-run introductions: they are covered separately.
    SharedPreferences.setMockInitialValues({
      'seen.instructions.lights': true,
      'seen.instructions.memory': true,
    });
    final storage = LocalStorage();
    await storage.init();

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ThinkrApp(storage: storage, registry: buildGameCatalog()),
    );
    await tester.pumpAndSettle();
    return storage;
  }

  Future<void> openGame(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  List<bool> lightsState(WidgetTester tester) => tester
      .widgetList<LightTile>(find.byType(LightTile))
      .map((tile) => tile.lit)
      .toList();

  MemoryPuzzle memoryPuzzle(int level) {
    final game = buildGameCatalog().byId('memory')!;
    return MemoryPuzzle(level: level, seed: game.seedForLevel(level));
  }

  /// Plays every pattern of a Memory level, stopping once the completion
  /// sheet has appeared.
  Future<void> solveMemoryLevel(WidgetTester tester, int level) async {
    final puzzle = memoryPuzzle(level);
    for (final pattern in puzzle.patterns) {
      // Wait out the reveal, then the previous round's "between" beat.
      await tester.pump(const Duration(milliseconds: 1800));
      for (final cell in pattern.toList()) {
        await tester.tap(find.byKey(ValueKey('memory-cell-$cell')));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pump(const Duration(milliseconds: 800));
    }
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
  }

  testWidgets('completing Memory clears the save and unlocks the next level',
      (tester) async {
    final storage = await launch(tester);
    await openGame(tester, 'MEMORY');
    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 1'), findsOneWidget);

    await solveMemoryLevel(tester, 1);
    expect(find.text('SOLVED'), findsOneWidget);

    // A completed level must never be offered as "Continue your game?".
    expect(storage.keysWithPrefix('gamestate.memory.'), isEmpty);
    // Progress was recorded for level 1.
    expect(storage.getJson('progress.memory'), isNotNull);
    expect(storage.getJson('progress.memory')!.containsKey('1'), isTrue);

    // Next level opens cleanly (no stale save resurrected).
    await tester.tap(find.text('Next Level'));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 2'), findsOneWidget);
    expect(find.text('Memorize'), findsOneWidget);

    // Back on the detail screen there is no unfinished game to continue.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE YOUR GAME?'), findsNothing);
    expect(find.text('Watch. Remember. Rebuild.'), findsOneWidget);
  });

  testWidgets('Reset button restarts the level and drops the saved attempt',
      (tester) async {
    final storage = await launch(tester);
    await openGame(tester, 'MEMORY');
    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1800));

    final correct = memoryPuzzle(1).patterns[0].first;
    await tester.tap(find.byKey(ValueKey('memory-cell-$correct')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(storage.keysWithPrefix('gamestate.memory.'), isNotEmpty);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Restart this level?'), findsOneWidget);

    // Cancel leaves everything untouched.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    // Restart restores the pristine level: counters, cards, feedback, save.
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('Memorize'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(storage.keysWithPrefix('gamestate.memory.'), isEmpty);
  });

  testWidgets('rapid tapping during feedback cannot corrupt the state',
      (tester) async {
    await launch(tester);
    await openGame(tester, 'MEMORY');
    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1800));

    final puzzle = memoryPuzzle(1);
    final correct = puzzle.patterns[0].first;
    final wrong = List.generate(9, (i) => i)
        .firstWhere((cell) => !puzzle.patterns[0].contains(cell));

    // A burst of taps with no frame in between: the input lock must
    // absorb every repeat while the success feedback plays.
    await tester.tap(find.byKey(ValueKey('memory-cell-$correct')));
    await tester.tap(find.byKey(ValueKey('memory-cell-$correct')));
    await tester.tap(find.byKey(ValueKey('memory-cell-$wrong')));
    await tester.tap(find.byKey(ValueKey('memory-cell-$wrong')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    // Still the same level, still consistent, exactly one move recorded.
    expect(find.text('LEVEL 1'), findsOneWidget);
    final moveLabel = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => t.data == '1')
        .length;
    expect(moveLabel, 1);
  });

  testWidgets('Lights resumes the exact board after leaving mid-level',
      (tester) async {
    final storage = await launch(tester);
    await openGame(tester, 'LIGHTS');
    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();

    final initial = lightsState(tester);
    expect(initial.length, 9);

    // Flip a tile (and its neighbours) — the board must visibly change.
    await tester.tap(find.byType(LightTile).first);
    await tester.pump(const Duration(milliseconds: 300));
    final changed = lightsState(tester);
    expect(changed, isNot(equals(initial)));
    expect(storage.keysWithPrefix('gamestate.lights.'), isNotEmpty);

    // Leave mid-level.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('CONTINUE YOUR GAME?'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);

    // Continue restores the exact same board — never reshuffled.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(lightsState(tester), equals(changed));

    // Playing onwards from the restored board keeps working.
    await tester.tap(find.byType(LightTile).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(lightsState(tester), isNot(equals(changed)));
  });

  testWidgets('Lights Reset restores the generated board and clears the save',
      (tester) async {
    final storage = await launch(tester);
    await openGame(tester, 'LIGHTS');
    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();

    final initial = lightsState(tester);
    await tester.tap(find.byType(LightTile).first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(lightsState(tester), isNot(equals(initial)));

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();

    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(lightsState(tester), equals(initial));
    expect(storage.keysWithPrefix('gamestate.lights.'), isEmpty);
  });

  testWidgets('a pending save survives an app restart', (tester) async {
    final storage = await launch(tester);
    await openGame(tester, 'LIGHTS');
    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LightTile).first);
    await tester.pump(const Duration(milliseconds: 300));
    final changed = lightsState(tester);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // Cold start on the same storage: the offer is still there.
    await tester.pumpWidget(
      ThinkrApp(storage: storage, registry: buildGameCatalog()),
    );
    await tester.pumpAndSettle();
    await openGame(tester, 'LIGHTS');
    expect(find.text('CONTINUE YOUR GAME?'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(lightsState(tester), equals(changed));
  });
}
