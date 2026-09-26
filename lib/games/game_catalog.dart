import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../core/models/game_definition.dart';
import '../core/models/puzzle_session.dart';
import '../core/services/game_registry.dart';
import 'lights/lights_game.dart';
import 'memory/memory_game.dart';
import 'shift/shift_game.dart';

/// The Thinkr catalog: three playable games today, more on the way.
///
/// Adding a game = appending one [GameDefinition] here. The home screen,
/// daily rotation, progress screen and level selection pick it up
/// automatically.
GameRegistry buildGameCatalog() => GameRegistry([
      _ComingSoonGame(
        id: 'one_line',
        name: 'One Line',
        tagline: 'Connect every edge exactly once.',
        icon: Icons.timeline_outlined,
        accent: GameAccents.oneLine,
        totalLevels: 50,
      ),
      ShiftGame(),
      LightsGame(),
      MemoryGame(),
      _ComingSoonGame(
        id: 'number_path',
        name: 'Number Path',
        tagline: 'Follow the sequence. Don\u2019t lift a finger.',
        icon: Icons.route_outlined,
        accent: GameAccents.numberPath,
        totalLevels: 50,
      ),
      _ComingSoonGame(
        id: 'pattern',
        name: 'Pattern',
        tagline: 'Find the rule hiding in the grid.',
        icon: Icons.auto_awesome_mosaic_outlined,
        accent: GameAccents.pattern,
        totalLevels: 40,
      ),
      _ComingSoonGame(
        id: 'split',
        name: 'Split',
        tagline: 'Divide the board. Obey the numbers.',
        icon: Icons.grid_on_outlined,
        accent: GameAccents.split,
        totalLevels: 40,
      ),
    ]);

/// Placeholder definition for an announced-but-unbuilt game. Never appears
/// in Daily, never enters gameplay; renders as a quiet "soon" row.
class _ComingSoonGame extends GameDefinition {
  _ComingSoonGame({
    required this.id,
    required this.name,
    required this.tagline,
    required this.icon,
    required this.accent,
    required this.totalLevels,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String tagline;
  @override
  final IconData icon;
  @override
  final Color accent;
  @override
  final int totalLevels;

  @override
  String get instructions => 'This game is still being designed.';

  @override
  bool get isAvailable => false;

  @override
  PuzzleGameWidget createBoard(PuzzleSession session) =>
      throw UnimplementedError('$id is not implemented yet');
}
