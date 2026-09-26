import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinkr/app/app.dart';
import 'package:thinkr/core/storage/local_storage.dart';
import 'package:thinkr/games/game_catalog.dart';
import 'package:thinkr/games/lights/lights_tile.dart';

void main() {
  testWidgets('home → game detail → gameplay flows work end to end',
      (tester) async {
    // Pre-seed the "introduction seen" flags so this test exercises the
    // navigation flows; the intro itself is covered in
    // memory_lifecycle_test.dart.
    SharedPreferences.setMockInitialValues({
      'seen.instructions.lights': true,
      'seen.instructions.memory': true,
    });
    final storage = LocalStorage();
    await storage.init();

    // Tall surface so the whole home list is materialized.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ThinkrApp(storage: storage, registry: buildGameCatalog()),
    );
    await tester.pumpAndSettle();

    // Home shows the greeting and the game cards.
    expect(find.text('Thinkr'), findsOneWidget);
    expect(find.text('SHIFT'), findsOneWidget);
    expect(find.text('LIGHTS'), findsOneWidget);
    expect(find.text('MEMORY'), findsOneWidget);

    // Coming-soon games stay quiet, out of the way.
    expect(find.text('One Line'), findsOneWidget);
    expect(find.text('SOON'), findsWidgets);

    // Open Lights.
    await tester.tap(find.text('LIGHTS'));
    await tester.pumpAndSettle();
    expect(find.text('Turn every light off.'), findsOneWidget);

    // Open level 1 from the grid.
    await tester.tap(find.text('01').first);
    await tester.pumpAndSettle();

    // Gameplay shell shows the level label and shared controls.
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('Hint'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('MOVES'), findsOneWidget);

    // Tap a Lights tile: the move counter responds.
    await tester.tap(find.byType(LightTile).first);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('tabs switch without losing state', (tester) async {
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

    await tester.tap(find.text('Duel'));
    await tester.pumpAndSettle();
    expect(find.text('MULTIPLAYER'), findsOneWidget);

    await tester.tap(find.text('Progress'));
    await tester.pumpAndSettle();
    expect(find.text('Your journey starts here.'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Haptics'), findsOneWidget);

    // Back to Games: greeting is still there (state preserved).
    await tester.tap(find.text('Games'));
    await tester.pumpAndSettle();
    expect(find.text('Thinkr'), findsOneWidget);
  });
}
