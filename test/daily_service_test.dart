import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thinkr/core/services/daily_service.dart';
import 'package:thinkr/core/services/game_registry.dart';
import 'package:thinkr/core/storage/local_storage.dart';
import 'package:thinkr/games/game_catalog.dart';

void main() {
  late LocalStorage storage;
  late GameRegistry registry;
  late DailyService daily;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalStorage();
    await storage.init();
    registry = buildGameCatalog();
    daily = DailyService(storage);
  });

  test('plan is stable for a given day and rotates across days', () {
    final monday = DateTime(2026, 9, 14);
    final tuesday = DateTime(2026, 9, 15);

    final planMon1 = daily.planFor(monday, registry);
    final planMon2 = daily.planFor(monday, registry);
    expect(planMon1.game.id, planMon2.game.id);
    expect(planMon1.seed, planMon2.seed);

    expect(planMon1.game.isAvailable, isTrue);
    // Two days rotate within the available games.
    final planTue = daily.planFor(tuesday, registry);
    expect(registry.available, contains(planMon1.game));
    expect(registry.available, contains(planTue.game));
  });

  test('completion is idempotent for the same day', () async {
    final now = DateTime(2026, 9, 20, 15, 30);
    final first = await daily.completeToday(
      now,
      gameId: 'lights',
      moves: 12,
      seconds: 40,
    );
    final second = await daily.completeToday(
      now,
      gameId: 'lights',
      moves: 99,
      seconds: 999,
    );
    expect(first, isTrue);
    expect(second, isFalse);
    expect(daily.recordToday(now)!.moves, 12);
  });

  test('streak counts consecutive completed days', () async {
    final today = DateTime(2026, 9, 20);
    // Two days in a row.
    await daily.completeToday(
      today.subtract(const Duration(days: 1)),
      gameId: 'lights',
      moves: 1,
      seconds: 1,
    );
    await daily.completeToday(today, gameId: 'lights', moves: 1, seconds: 1);
    expect(daily.streak(today), 2);

    // A gap breaks the streak.
    expect(
      daily.streak(today.subtract(const Duration(days: 2))),
      0,
    );
  });

  test('recent history covers the last 7 days oldest first', () {
    final now = DateTime(2026, 9, 20);
    final history = daily.recentHistory(now);
    expect(history.length, 7);
    expect(history.last.day, DateTime(2026, 9, 20));
    expect(history.first.day, DateTime(2026, 9, 14));
    expect(history.every((entry) => !entry.isCompleted), isTrue);
  });
}
