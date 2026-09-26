import 'package:flutter/material.dart';

import 'game_definition.dart';

enum PuzzleMode { solo, twoPlayer }

/// Restored in-progress state for a level.
///
/// [moves] and [seconds] are tracked by the gameplay shell; [details] is
/// the board's own serialized payload (card arrangement, found cells,
/// mistakes, …). Produced by `GameStateManager` when the player chooses
/// "Continue your game?".
class LevelResumeState {
  const LevelResumeState({
    required this.moves,
    required this.seconds,
    required this.details,
  });

  final int moves;
  final int seconds;
  final Map<String, dynamic> details;
}

/// Everything a game board needs to run inside the shared gameplay shell.
///
/// Sessions are created by the shell — games never navigate, persist data
/// or know about ads. They talk to the shell through [PuzzleHost].
class PuzzleSession {
  PuzzleSession({
    required this.game,
    required this.seed,
    this.level,
    this.isDaily = false,
    this.mode = PuzzleMode.solo,
    this.resume,
  });

  /// A session for a solvable level of [game] from the level grid. The
  /// seed is deterministic per level, so a level always plays the same
  /// way — and a resumed level lines up with the attempt it restores.
  factory PuzzleSession.forLevel(
    GameDefinition game,
    int level, {
    LevelResumeState? resume,
    PuzzleMode mode = PuzzleMode.solo,
  }) =>
      PuzzleSession(
        game: game,
        level: level,
        seed: game.seedForLevel(level),
        mode: mode,
        resume: resume,
      );

  final GameDefinition game;

  /// `null` for the daily challenge.
  final int? level;

  final bool isDaily;
  final PuzzleMode mode;
  final int seed;

  /// In-progress state to restore, or null when starting fresh. Only the
  /// shell sets this (before the board is created); boards read it in
  /// their `initState()`.
  final LevelResumeState? resume;

  /// First-move nudge for brand-new players. Only the shell sets these
  /// (before the board exists, mirroring [resume]): the text renders as a
  /// quiet line above the board until the first move; boards pulse
  /// [firstMoveNudgeCell] with their existing hint styling until the
  /// first tap. Both stay null unless this is a fresh level 1 for a
  /// player who has never completed any level.
  String? firstMoveNudgeText;
  int? firstMoveNudgeCell;

  /// Shell-installed callbacks for moves, failures and solves.
  final PuzzleHostBridge host = PuzzleHostBridge();

  /// Bridge used by the hint system: the shell asks the board to reveal a
  /// game-specific hint after a reward has been earned.
  final HintBridge hintBridge = HintBridge();

  /// Board → shell channel for progress snapshots. Boards register a
  /// snapshot provider; the shell pulls it when persisting in-progress
  /// state (back, dispose, app backgrounded).
  final ProgressBridge progressBridge = ProgressBridge();

  /// Quiet status line under the header (e.g. "Memorize", "Player 1's turn").
  final NoteChannel note = NoteChannel();

  String get headerLabel {
    if (isDaily) return 'Daily';
    return 'Level $level';
  }

  /// Chapter arc for the header's second line (null for daily sessions).
  String? get headerSublabel {
    if (isDaily || level == null) return null;
    return game.chapterName(game.chapterOf(level!));
  }

  /// A copy of this session without restored state — used by Restart,
  /// so a restarted level never resumes the abandoned attempt.
  PuzzleSession withoutResume() => PuzzleSession(
        game: game,
        seed: seed,
        level: level,
        isDaily: isDaily,
        mode: mode,
      )
        ..firstMoveNudgeText = firstMoveNudgeText
        ..firstMoveNudgeCell = firstMoveNudgeCell;
}

/// Game-agnostic callback surface between a board and the gameplay shell.
/// Boards call these; the shell implements the behavior (counters, haptics,
/// persistence, completion flow).
abstract interface class PuzzleHost {
  /// Register a valid move. Starts the timer on the first move.
  void move();

  /// Feedback for an illegal/incorrect action.
  ///
  /// [countsAsFailure] marks it as a real failed attempt (drives the
  /// quiet "still stuck?" support flow after ~3 attempts).
  void invalidMove({bool countsAsFailure = false});

  /// The puzzle is solved. [optimalMoves] enables perfect-solve tracking.
  /// [summary] is an optional result line (e.g. "Player 1 wins 4–2").
  void solve({String? summary, int? optimalMoves});

  /// The board judges the player genuinely stuck (e.g. far more moves
  /// than optimal). The shell may quietly offer help — once, optionally.
  void requestSupport();

  /// The board replayed itself (e.g. from the "Wrong move" prompt).
  /// The shell resets its counters and drops the level's saved state.
  void onLevelRestarted();

  /// Per-game tactile/audio personality. Boards request the *kind* of
  /// feedback; the shell maps it to the central services so games never
  /// touch the platform.
  void playSlideFeedback(); // Shift: tile slid into the gap
  void playFlipFeedback(); // Lights: tile flipped
  void playMatchFeedback(); // Memory: cell matched
}

/// Concrete bridge installed by the shell. Defaults are safe no-ops so a
/// board can never crash the app if it outlives its shell.
///
/// Bindings are owner-scoped: when the shell is replaced (Reset, Replay,
/// Next Level use `pushReplacement`), the outgoing screen's `dispose()`
/// runs *after* the incoming screen's `initState()`. Owner tokens guarantee
/// the outgoing screen can only detach its own callbacks, never the new
/// screen's.
class PuzzleHostBridge implements PuzzleHost {
  Object? _owner;
  void Function()? _move;
  void Function(bool countsAsFailure)? _invalidMove;
  void Function(String? summary, int? optimalMoves)? _solve;
  void Function()? _support;
  void Function()? _restart;
  void Function()? _slideFeedback;
  void Function()? _flipFeedback;
  void Function()? _matchFeedback;

  void bind(
    Object owner, {
    required void Function() onMove,
    required void Function(bool countsAsFailure) onInvalidMove,
    required void Function(String? summary, int? optimalMoves) onSolve,
    required void Function() onSupport,
    required void Function() onLevelRestarted,
    void Function()? onSlideFeedback,
    void Function()? onFlipFeedback,
    void Function()? onMatchFeedback,
  }) {
    _owner = owner;
    _move = onMove;
    _invalidMove = onInvalidMove;
    _solve = onSolve;
    _support = onSupport;
    _restart = onLevelRestarted;
    _slideFeedback = onSlideFeedback;
    _flipFeedback = onFlipFeedback;
    _matchFeedback = onMatchFeedback;
  }

  /// Only the owner that bound may unbind.
  void unbind(Object owner) {
    if (_owner == null || !identical(_owner, owner)) return;
    _owner = null;
    _move = null;
    _invalidMove = null;
    _solve = null;
    _support = null;
    _restart = null;
    _slideFeedback = null;
    _flipFeedback = null;
    _matchFeedback = null;
  }

  @override
  void move() => _move?.call();

  @override
  void invalidMove({bool countsAsFailure = false}) =>
      _invalidMove?.call(countsAsFailure);

  @override
  void solve({String? summary, int? optimalMoves}) =>
      _solve?.call(summary, optimalMoves);

  @override
  void requestSupport() => _support?.call();

  @override
  void onLevelRestarted() => _restart?.call();

  @override
  void playSlideFeedback() => _slideFeedback?.call();

  @override
  void playFlipFeedback() => _flipFeedback?.call();

  @override
  void playMatchFeedback() => _matchFeedback?.call();
}

/// Board → shell channel for progress snapshots (save/resume support).
///
/// The board registers a provider in initState (unregistration uses
/// tear-off equality, so a replaced screen's dispose can never remove the
/// new screen's provider). The shell pulls a snapshot when persisting
/// in-progress state — on back, on dispose, and when the app is
/// backgrounded.
class ProgressBridge {
  Map<String, dynamic>? Function()? _provider;

  void register(Map<String, dynamic>? Function() provider) =>
      _provider = provider;

  void unregister(Map<String, dynamic>? Function() provider) {
    if (_provider == provider) _provider = null;
  }

  /// The board's serialized state, or null when there is nothing
  /// meaningful to save.
  Map<String, dynamic>? snapshot() => _provider?.call();
}

/// A game-specific hint. The board performs its own visual reveal and
/// returns a short message the shell displays as a quiet inline banner.
class PuzzleHint {
  const PuzzleHint(this.message, {this.displayFor = const Duration(seconds: 6)});

  final String message;
  final Duration displayFor;
}

/// Connects the shell's hint flow to the live board state without
/// global keys or service access inside games.
class HintBridge {
  PuzzleHint? Function()? _provider;

  /// Called by the board's state in [State.initState].
  void register(PuzzleHint? Function() provider) => _provider = provider;

  /// Tear-off equality (not identity) so a replaced screen's dispose can
  /// only unregister its own provider, never the new screen's.
  void unregister(PuzzleHint? Function() provider) {
    if (_provider == provider) _provider = null;
  }

  PuzzleHint? request() => _provider?.call();
}

/// Quiet status line channel between board and shell.
///
/// The current value is stored so the shell can seed it when a session
/// starts ([seed]) and read it at any time ([value]).
///
/// Listener registration is owner-scoped for the same reason as
/// [PuzzleHostBridge]: with `pushReplacement` the outgoing screen's
/// `dispose()` runs after the incoming screen's `initState()`, and the
/// outgoing screen must only remove its own listener.
///
/// Lifecycle rule: [emit] must never be called from a board's
/// `initState()`/`build()` — the shell is building at that moment, so any
/// listener `setState` would throw "setState called during build". Boards
/// define their initial note via `GameDefinition.initialNoteFor` (seeded
/// by the shell before subscribing) and emit only from timers or
/// user-interaction callbacks.
class NoteChannel {
  final Map<Object, void Function(String? note)> _listeners = {};
  String? _value;

  String? get value => _value;

  /// Writes the initial value without notifying. Used when a session
  /// starts, before any screen has subscribed.
  void seed(String? note) => _value = note;

  void listen(Object owner, void Function(String? note) listener) =>
      _listeners[owner] = listener;

  /// Only the owner that listened may remove itself.
  void removeListener(Object owner) => _listeners.remove(owner);

  /// Notifies listeners outside the build phase. No-op when the value
  /// did not change, so duplicated emissions can never cascade rebuilds.
  void emit(String? note) {
    if (_value == note) return;
    _value = note;
    for (final listener in _listeners.values.toList(growable: false)) {
      listener(note);
    }
  }
}

/// Base class for game boards. Keeps the session and nothing else.
abstract class PuzzleGameWidget extends StatefulWidget {
  const PuzzleGameWidget({super.key, required this.session});

  final PuzzleSession session;
}
