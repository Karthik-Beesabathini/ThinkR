import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinkr/core/services/game_state_service.dart';
import 'package:thinkr/core/storage/local_storage.dart';

void main() {
  late LocalStorage storage;
  late GameStateManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorage();
    await storage.init();
    manager = GameStateManager(storage);
  });

  SavedGameState state({
    String gameId = 'memory',
    int level = 7,
    int moves = 12,
    int seconds = 84,
  }) =>
      SavedGameState(
        gameId: gameId,
        level: level,
        moves: moves,
        seconds: seconds,
        details: {'pattern': 2, 'mistakes': 1, 'found': [3, 4]},
        savedAt: DateTime(2026, 9, 20, 12, 30 + level),
      );

  test('save/load round trip preserves every field', () async {
    await manager.saveGameState(state());

    expect(manager.hasSavedGame('memory'), isTrue);
    final loaded = manager.loadGameState('memory', 7);
    expect(loaded, isNotNull);
    expect(loaded!.level, 7);
    expect(loaded.moves, 12);
    expect(loaded.seconds, 84);
    expect(loaded.details['pattern'], 2);
    expect(loaded.details['mistakes'], 1);
    expect(loaded.details['found'], [3, 4]);
  });

  test('load returns null for unknown levels and unknown games', () async {
    expect(manager.loadGameState('memory', 7), isNull);
    await manager.saveGameState(state());
    expect(manager.loadGameState('memory', 8), isNull);
    expect(manager.loadGameState('lights', 7), isNull);
    expect(manager.hasSavedGame('lights'), isFalse);
  });

  test('latestSavedGame picks the most recently saved level', () async {
    await manager.saveGameState(state(level: 3, moves: 2));
    await manager.saveGameState(state(level: 7, moves: 12));

    final latest = manager.latestSavedGame('memory');
    expect(latest, isNotNull);
    expect(latest!.level, 7);
  });

  test('clear removes exactly the requested level', () async {
    await manager.saveGameState(state(level: 3));
    await manager.saveGameState(state(level: 7));

    await manager.clearGameState('memory', 3);
    expect(manager.loadGameState('memory', 3), isNull);
    expect(manager.loadGameState('memory', 7), isNotNull);
    expect(manager.hasSavedGame('memory'), isTrue);

    await manager.clearGameState('memory', 7);
    expect(manager.hasSavedGame('memory'), isFalse);
  });

  test('clearAllGames wipes every game', () async {
    await manager.saveGameState(state(gameId: 'memory'));
    await manager.saveGameState(state(gameId: 'lights', level: 2));

    await manager.clearAllGames();
    expect(manager.hasSavedGame('memory'), isFalse);
    expect(manager.hasSavedGame('lights'), isFalse);
  });

  test('notifies listeners on save and clear', () async {
    var notifications = 0;
    manager.addListener(() => notifications++);
    await manager.saveGameState(state());
    expect(notifications, 1);
    await manager.clearGameState('memory', 7);
    expect(notifications, 2);
  });

  test('malformed persisted payloads degrade to fresh starts', () async {
    // A corrupt entry must never crash the resume flow — it degrades to a
    // fresh start for that level.
    SharedPreferences.setMockInitialValues({
      'gamestate.memory.7':
          '{"level": 7, "moves": 3, "seconds": 10, "details": {}}',
    });
    storage = LocalStorage();
    await storage.init();
    manager = GameStateManager(storage);
    final loaded = manager.loadGameState('memory', 7);
    expect(loaded, isNotNull);
    expect(loaded!.level, 7);
    expect(loaded.moves, 3);
    expect(loaded.details, isEmpty);
  });
}
