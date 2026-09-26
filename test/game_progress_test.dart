import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinkr/core/models/game_progress.dart';
import 'package:thinkr/core/services/game_registry.dart';
import 'package:thinkr/core/services/progress_service.dart';
import 'package:thinkr/core/storage/local_storage.dart';
import 'package:thinkr/games/game_catalog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameProgressData', () {
    test('currentLevel is the first unsolved level', () {
      final data = GameProgressData();
      expect(data.currentLevel, 1);
      data.completed[1] = const LevelRecord(moves: 5, seconds: 10);
      expect(data.currentLevel, 2);
      data.completed[2] = const LevelRecord(moves: 4, seconds: 9);
      expect(data.currentLevel, 3);
    });

    test('unlocking requires the previous level', () {
      final data = GameProgressData();
      expect(data.isUnlocked(1), isTrue);
      expect(data.isUnlocked(2), isFalse);
      data.completed[1] = const LevelRecord(moves: 5, seconds: 10);
      expect(data.isUnlocked(2), isTrue);
      expect(data.isUnlocked(3), isFalse);
    });

    test('betterOf keeps the stronger record', () {
      const fewer = LevelRecord(moves: 3, seconds: 40);
      const slower = LevelRecord(moves: 5, seconds: 10);
      expect(fewer.betterOf(slower), same(fewer));
      expect(slower.betterOf(fewer), same(fewer));

      const perfect = LevelRecord(moves: 6, seconds: 60, perfect: true);
      const plain = LevelRecord(moves: 4, seconds: 20);
      expect(perfect.betterOf(plain), same(perfect));
      expect(plain.betterOf(perfect), same(perfect));
    });
  });

  group('ProgressService', () {
    late LocalStorage storage;
    late GameRegistry registry;
    late ProgressService progress;

    setUp(() async {
      storage = LocalStorage();
      await storage.init();
      registry = buildGameCatalog();
      progress = ProgressService(storage);
      progress.load(registry);
    });

    test('records results and counts solves once', () {
      final game = registry.byId('lights')!;
      progress.recordLevelResult(
        game,
        level: 1,
        moves: 4,
        seconds: 12,
        perfect: false,
      );
      expect(progress.totalSolved, 1);
      expect(progress.progressOf(game).isCompleted(1), isTrue);

      // Re-solving must not double count.
      progress.recordLevelResult(
        game,
        level: 1,
        moves: 3,
        seconds: 9,
        perfect: true,
      );
      expect(progress.totalSolved, 1);
      expect(progress.progressOf(game).completed[1]!.moves, 3);
      expect(progress.progressOf(game).completed[1]!.perfect, isTrue);
      expect(progress.hintsUsed, 0);
    });

    test('continue level follows progress and last play', () {
      final game = registry.byId('lights')!;
      expect(progress.continueLevel(game), 1);
      progress.recordLevelResult(
        game,
        level: 1,
        moves: 4,
        seconds: 12,
        perfect: false,
      );
      expect(progress.continueLevel(game), 2);
    });

    test('progress persists across reloads', () async {
      final game = registry.byId('shift')!;
      progress.recordLevelResult(
        game,
        level: 1,
        moves: 21,
        seconds: 30,
        perfect: false,
      );
      progress.recordHintUsed();

      final reloaded = ProgressService(storage)..load(registry);
      expect(reloaded.totalSolved, 1);
      expect(reloaded.hintsUsed, 1);
      expect(reloaded.progressOf(game).isCompleted(1), isTrue);
      expect(reloaded.lastGameId, 'shift');
    });

    test('reset clears everything but keeps settings storage separate', () async {
      final game = registry.byId('memory')!;
      progress.recordLevelResult(
        game,
        level: 1,
        moves: 6,
        seconds: 8,
        perfect: true,
      );
      await progress.resetProgress();
      expect(progress.totalSolved, 0);
      expect(progress.progressOf(game).isCompleted(1), isFalse);
    });
  });
}
