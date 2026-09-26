import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinkr/app/app.dart';
import 'package:thinkr/core/storage/local_storage.dart';
import 'package:thinkr/games/game_catalog.dart';
import 'package:thinkr/games/memory/memory_puzzle.dart';

/// Regression tests for the "setState() or markNeedsBuild() called during
/// build" error in the Memory game.
///
/// The old MemoryBoard emitted to the session's NoteChannel from
/// initState(), which ran while GamePlayScreen was building — mutating an
/// ancestor during the build phase. These tests drive the full lifecycle
/// (open → play → complete → next level → reset → reopen) and fail the
/// test run if Flutter ever reports that exception again.
void main() {
  Future<void> launch(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorage();
    await storage.init();

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ThinkrApp(storage: storage, registry: buildGameCatalog()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('memory lifecycle: open, play, complete, next level, reset',
      (tester) async {
    await launch(tester);

    // Open the Memory game detail, then level 1.
    await tester.tap(find.text('MEMORY'));
    await tester.pumpAndSettle();
    expect(find.text('Watch. Remember. Rebuild.'), findsOneWidget);

    // First-time introduction: shown once on first open of the game, with
    // the two rule sections and a "Got it" button.
    expect(find.text('HOW IT WORKS'), findsOneWidget);
    expect(find.text('HOW TO PLAY'), findsOneWidget);
    expect(find.text('A pattern of cells flashes briefly — memorize it.'),
        findsOneWidget);
    expect(find.text('Watch the flashing pattern closely while it lasts.'),
        findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();

    expect(find.text('LEVEL 1'), findsOneWidget);
    // The starting status line is seeded without touching setState.
    expect(find.text('Memorize'), findsOneWidget);

    // Level 1: two patterns of three cells on a 3x3 board.
    final game = buildGameCatalog().byId('memory')!;
    final puzzle = MemoryPuzzle(level: 1, seed: game.seedForLevel(1));
    expect(puzzle.patternCount, 2);

    // Show phase → recall phase.
    await tester.pump(const Duration(milliseconds: 1800));

    // Round 1: tap the three pattern cells.
    for (final cell in puzzle.patterns[0].toList()) {
      await tester.tap(find.byKey(ValueKey('memory-cell-$cell')));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Round 2 begins (show → recall).
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 1800));
    for (final cell in puzzle.patterns[1].toList()) {
      await tester.tap(find.byKey(ValueKey('memory-cell-$cell')));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Solved → completion sheet.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('SOLVED'), findsOneWidget);
    expect(find.text('Next Level'), findsOneWidget);

    // Next level loads cleanly (pushReplacement race: the old screen's
    // dispose must not detach the new screen's note/host bindings).
    await tester.tap(find.text('Next Level'));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 2'), findsOneWidget);
    expect(find.text('Memorize'), findsOneWidget);

    // Reset via the gameplay menu.
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restart level'));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 2'), findsOneWidget);
    expect(find.text('Memorize'), findsOneWidget);

    // "How to play" in the gameplay menu shows the same two-section rules.
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How to play'));
    await tester.pumpAndSettle();
    expect(find.text('HOW IT WORKS'), findsOneWidget);
    expect(find.text('HOW TO PLAY'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // Leave and reopen the game — fresh session, no errors.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('02').first);
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 2'), findsOneWidget);
  });

  testWidgets('memory note line updates outside build without errors',
      (tester) async {
    await launch(tester);

    await tester.tap(find.text('MEMORY'));
    await tester.pumpAndSettle();

    // Dismiss the first-time introduction (fresh storage in this test).
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();

    expect(find.text('Memorize'), findsOneWidget);

    // The show→recall transition is driven by a controller timer that
    // forwards the new note to the shell — all outside the build phase.
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('Rebuild the pattern'), findsOneWidget);
  });
}
