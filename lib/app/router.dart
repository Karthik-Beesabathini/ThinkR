import 'package:flutter/material.dart';

import '../core/models/game_definition.dart';
import '../core/models/puzzle_session.dart';
import '../core/multiplayer/nearby_host_session.dart';
import '../features/game_detail/game_detail_screen.dart';
import '../features/gameplay/gameplay_screen.dart';
import '../features/multiplayer/nearby_duel_screen.dart';

/// All navigation goes through this small router. Routes are built with a
/// shared quick fade-through-slide transition — calm, short, consistent.
abstract final class AppRouter {
  static const _transitionDuration = Duration(milliseconds: 260);

  static PageRoute<T> _route<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: _transitionDuration,
      reverseTransitionDuration: _transitionDuration,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  static Future<T?> pushGameDetail<T extends Object?>(
    BuildContext context,
    GameDefinition game,
  ) {
    return Navigator.of(context, rootNavigator: true)
        .push<T>(_route(GameDetailScreen(game: game)));
  }

  static Future<T?> pushGameplay<T extends Object?>(
    BuildContext context,
    PuzzleSession session,
  ) {
    return Navigator.of(context, rootNavigator: true)
        .push<T>(_route(GameplayScreen(session: session)));
  }

  /// Full-screen nearby duel with the shared calm transition.
  static Future<T?> pushNearbyDuel<T extends Object?>(
    BuildContext context,
    NearbyRole role,
  ) {
    return Navigator.of(context, rootNavigator: true)
        .push<T>(_route(NearbyDuelScreen(role: role)));
  }

  /// Replaces the current gameplay screen (Next Level / Replay).
  static void replaceGameplay(BuildContext context, PuzzleSession session) {
    Navigator.of(context, rootNavigator: true)
        .pushReplacement(_route(GameplayScreen(session: session)));
  }

  static void pop<T extends Object?>(BuildContext context, [T? result]) =>
      Navigator.of(context, rootNavigator: true).pop(result);
}
