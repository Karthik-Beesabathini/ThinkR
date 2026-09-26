import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinkr/app/app.dart';
import 'package:thinkr/core/storage/local_storage.dart';
import 'package:thinkr/games/game_catalog.dart';
import 'package:thinkr/games/memory/memory_puzzle.dart';

/// Save/resume regression tests for the Memory game:
/// leaving mid-level must persist, reopening must offer "Continue your
/// game?", and Continue must restore the exact state (moves, timer,
/// found cells) without reshuffling.
void main() {
  testWidgets('leaving mid-level saves; continue restores the exact state',
      (tester) async {
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

    // Open Memory (dismiss the first-time introduction).
    await tester.tap(find.text('MEMORY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    // Open level 1 and reach the recall phase.
    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));

    // One correct tap: moves = 1, one cell found.
    final game = buildGameCatalog().byId('memory')!;
    final puzzle = MemoryPuzzle(level: 1, seed: game.seedForLevel(1));
    final correctCell = puzzle.patterns[0].first;
    await tester.tap(find.byKey(ValueKey('memory-cell-$correctCell')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('1'), findsWidgets); // moves counter

    // Leave mid-level: the shell saves on dispose.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // The detail screen now offers the unfinished game.
    expect(find.text('CONTINUE YOUR GAME?'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('1 moves · 00:0'), findsNothing); // sanity: full label
    expect(find.textContaining('1 moves ·'), findsOneWidget);
    expect(find.textContaining('00:'), findsOneWidget);

    // Continue: exact state, no reshuffle.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('Rebuild the pattern'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // moves restored
    // The previously found cell is still ticked — state restored.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    // Continuing play keeps working from the restored state.
    final secondCell = puzzle.patterns[0].toList()[1];
    await tester.tap(find.byKey(ValueKey('memory-cell-$secondCell')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('restart on the resume card starts a fresh level', (tester) async {
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

    await tester.tap(find.text('MEMORY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 1800));

    final game = buildGameCatalog().byId('memory')!;
    final puzzle = MemoryPuzzle(level: 1, seed: game.seedForLevel(1));
    await tester.tap(
        find.byKey(ValueKey('memory-cell-${puzzle.patterns[0].first}')));
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // Restart clears the saved attempt and opens the level fresh.
    await tester.tap(find.text('Restart'));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('Memorize'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });
}
