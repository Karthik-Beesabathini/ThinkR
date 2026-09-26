import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinkr/app/app.dart';
import 'package:thinkr/core/storage/local_storage.dart';
import 'package:thinkr/games/game_catalog.dart';
import 'package:thinkr/games/memory/memory_puzzle.dart';

/// UI-level coverage for the Memory card feedback loop:
/// a correct tap shows a tick, an incorrect tap shows a cross plus the
/// small "Wrong move" prompt with Replay / Try again, and hammering the
/// cards during the feedback window cannot corrupt the state.
void main() {
  /// Drives the app to an interactive Memory level 1.
  Future<MemoryPuzzle> openLevel(
    WidgetTester tester,
    LocalStorage storage,
  ) async {
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

    // Let the "show" phase elapse: the board becomes interactive.
    await tester.pump(const Duration(milliseconds: 1800));

    final game = buildGameCatalog().byId('memory')!;
    return MemoryPuzzle(level: 1, seed: game.seedForLevel(1));
  }

  testWidgets('correct tap shows a tick, wrong tap shows a cross',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorage();
    await storage.init();
    final puzzle = await openLevel(tester, storage);

    final correct = puzzle.patterns[0].first;
    final wrong = List.generate(9, (i) => i)
        .firstWhere((cell) => !puzzle.patterns[0].contains(cell));

    // Correct → tick on the cell, no cross anywhere.
    await tester.tap(find.byKey(ValueKey('memory-cell-$correct')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(find.text('Wrong move'), findsNothing);

    // Wait out the success lock, then tap a wrong cell.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(ValueKey('memory-cell-$wrong')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    // The earlier tick is still there — a mistake does not wipe the round.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('wrong move raises the prompt and rapid taps are ignored',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = LocalStorage();
    await storage.init();
    final puzzle = await openLevel(tester, storage);

    final correct = puzzle.patterns[0].first;
    final wrong = List.generate(9, (i) => i)
        .firstWhere((cell) => !puzzle.patterns[0].contains(cell));

    await tester.tap(find.byKey(ValueKey('memory-cell-$wrong')));

    // Rapid tapping inside the feedback window must be swallowed: the
    // board is locked, so the mistakes count stays at one.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(ValueKey('memory-cell-$correct')));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    // The compact prompt appears after the error beat: title + both actions.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Wrong move'), findsOneWidget);
    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    // "Try again" re-shows the same pattern and keeps the level alive.
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Wrong move'), findsNothing);
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Memorize'), findsOneWidget);
    expect(find.text('LEVEL 1'), findsOneWidget);
  });
}
