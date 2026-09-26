import '../models/game_definition.dart';

/// The single source of games. Adding a game = adding a definition here.
/// Navigation, home, daily, progress and the gameplay shell are unchanged.
class GameRegistry {
  const GameRegistry(this.games);

  final List<GameDefinition> games;

  List<GameDefinition> get available =>
      games.where((game) => game.isAvailable).toList(growable: false);

  List<GameDefinition> get comingSoon =>
      games.where((game) => !game.isAvailable).toList(growable: false);

  GameDefinition? byId(String id) {
    for (final game in games) {
      if (game.id == id) return game;
    }
    return null;
  }

  int get totalLevels =>
      games.fold(0, (sum, game) => sum + game.totalLevels);
}
