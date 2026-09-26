import 'dart:async';

import 'package:flutter/foundation.dart';

import 'memory_puzzle.dart';

enum MemoryPhase { showing, recall, between, done }

/// Pure-Dart controller for the Memory board.
///
/// Owns every piece of game state (phase, revealed cells, note line, duel
/// scores) and every timer. It knows nothing about widgets or
/// BuildContext, so it can never mutate a widget tree at the wrong moment.
///
/// Lifecycle contract with the view:
///  - created exactly once in the board's `initState()` (never in
///    `build()`), so rebuilds can never re-initialize or re-shuffle,
///  - notifies listeners only from timers or tap callbacks — i.e. always
///    outside the build phase,
///  - every timer callback is guarded by [_disposed],
///  - [dispose] cancels all pending timers, so a replaced board can never
///    fire into a dead widget tree.
class MemoryGameController extends ChangeNotifier {
  MemoryGameController({
    required int level,
    required int seed,
    required bool duel,
    required this.onMove,
    required this.onInvalidMove,
    required this.onSolved,
    required this.onRestart,
    this.onMatch,
    Map<String, dynamic>? saved,
  }) : _duel = duel, // ignore: prefer_initializing_formals
       _puzzle = MemoryPuzzle(level: level, seed: seed) {
    // Restore in-progress state (save/resume). The deal itself is
    // deterministic from level+seed, so only progress needs saving — the
    // board is never reshuffled on reopen.
    _mistakes = (saved?['mistakes'] as num?)?.toInt() ?? 0;
    final pattern = (saved?['pattern'] as num?)?.toInt() ?? 0;
    _foundCells = ((saved?['found'] as List?) ?? const [])
        .map((cell) => (cell as num).toInt())
        .toSet();
    final resumable = !_duel && pattern > 0 && pattern < _puzzle.patternCount;
    final midRecall = isMidRecall(level: level, duel: _duel, saved: saved);

    if (midRecall) {
      // Continue exactly where the player stopped.
      _puzzle.restoreToPattern(pattern);
      _phase = MemoryPhase.recall;
      _note = 'Rebuild the pattern';
      notifyListeners();
    } else if (resumable) {
      // Re-show the round the player was on.
      _puzzle.restoreToPattern(pattern);
      _beginPattern();
    } else {
      _note = memorizeNote(duel: _duel, player: _currentPlayer);
      _beginPattern();
    }
  }

  final MemoryPuzzle _puzzle;
  final bool _duel;
  final void Function() onMove;
  final void Function(bool countsAsFailure) onInvalidMove;
  final void Function(String? summary, int? optimalMoves) onSolved;
  final void Function() onRestart;

  /// Called on every correct tap so the shell can play its match
  /// feedback. Optional — tests construct without it.
  final void Function()? onMatch;

  static const int _duelRounds = 6;

  /// True when a saved payload resumes *mid-recall* — the player had already
  /// rebuilt part of a pattern when they left.
  ///
  /// Shared by the restore branch in the constructor and by [initialNote],
  /// so the shell's seeded status line can never disagree with the phase
  /// the controller actually opens in. Without this the resumed board
  /// displayed "Memorize" (the value seeded before the board existed) until
  /// the player happened to tap something.
  static bool isMidRecall({
    required int level,
    required bool duel,
    Map<String, dynamic>? saved,
  }) {
    if (duel || saved == null) return false;
    final pattern = (saved['pattern'] as num?)?.toInt() ?? 0;
    final found = (saved['found'] as List?) ?? const [];
    return saved['phase'] == 'recall' &&
        found.isNotEmpty &&
        pattern < MemoryPuzzle.patternCountForLevel(level);
  }

  /// The starting status line for a level — fresh or resumed.
  ///
  /// Called by the shell (through `GameDefinition.initialNoteFor`) *before*
  /// the board is created, because a board must never emit during its own
  /// `initState()` (that runs while the shell is building).
  static String initialNote({
    required int level,
    required bool duel,
    Map<String, dynamic>? saved,
  }) {
    if (isMidRecall(level: level, duel: duel, saved: saved)) {
      return 'Rebuild the pattern';
    }
    return memorizeNote(duel: duel, player: 1);
  }

  /// The "watch this, then rebuild it" line. Single source of truth so the
  /// seeded note and the live note can never drift apart.
  static String memorizeNote({required bool duel, required int player}) =>
      duel ? 'Player $player — memorize' : 'Memorize';

  MemoryPhase _phase = MemoryPhase.showing;
  Set<int> _shown = const <int>{};
  Set<int> _foundCells = <int>{};
  int? _errorCell;
  int _errorStamp = 0;
  bool _wrongPromptVisible = false;
  int _mistakes = 0;
  int _lockCount = 0;
  late String _note;
  bool _reported = false;
  bool _disposed = false;
  final List<Timer> _timers = [];

  // 2-player duel state.
  int _player1Score = 0;
  int _player2Score = 0;
  int _currentPlayer = 1;
  int _roundsPlayed = 0;

  MemoryPuzzle get puzzle => _puzzle;
  bool get isDuel => _duel;
  MemoryPhase get phase => _phase;
  Set<int> get shownCells => _shown;
  Set<int> get foundCells => _foundCells;
  int? get errorCell => _errorCell;
  int get errorStamp => _errorStamp;
  bool get wrongPromptVisible => _wrongPromptVisible;
  int get mistakes => _mistakes;
  String get note => _note;
  int get player1Score => _player1Score;
  int get player2Score => _player2Score;
  int get currentPlayer => _currentPlayer;

  /// Cells are only interactive while the player rebuilds the pattern and
  /// no feedback animation / prompt holds the lock.
  bool get interactive =>
      _phase == MemoryPhase.recall &&
      !_reported &&
      !_wrongPromptVisible &&
      _errorCell == null &&
      _lockCount == 0;

  void tap(int index) {
    if (!interactive) return;
    final result = _puzzle.tap(index);
    switch (result.kind) {
      case MemoryTapKind.hit:
        // Apply the state change *first*, then report the move: the shell
        // snapshots the board (for save/resume) inside `onMove`, so the
        // board must already be up to date when it is pulled. Reporting
        // first is what made a resumed game forget the cell just matched.
        _foundCells.add(index);
        _lock(const Duration(milliseconds: 120));
        onMatch?.call();
        onMove();
        notifyListeners();
      case MemoryTapKind.miss:
        if (!_duel) _mistakes++;
        // Incorrect: cross + shake on the cell, input locked, then the
        // small "Wrong move" prompt appears.
        _errorCell = index;
        _errorStamp++;
        _lock(const Duration(milliseconds: 650));
        onMove();
        onInvalidMove(!_duel);
        notifyListeners();
        _runAfter(const Duration(milliseconds: 650), () {
          if (_disposed || _reported) return;
          _wrongPromptVisible = true;
          notifyListeners();
        });
      case MemoryTapKind.patternComplete:
      case MemoryTapKind.completed:
        // Freeze the round before reporting the move, so a save taken
        // inside `onMove()` can never be read back as "mid-recall" of a
        // pattern the player never got to see.
        _freezeRound();
        onMove();
        _endPattern(success: true);
      case MemoryTapKind.ignored:
        break;
    }
  }

  /// "Try again" on the wrong-move prompt: dismiss the prompt, clear the
  /// error, and re-show the current pattern (solo) / pass the turn (duel).
  /// The mistake stays counted.
  void tryAgain() {
    if (!_wrongPromptVisible) return;
    _wrongPromptVisible = false;
    _errorCell = null;
    notifyListeners();
    _endPattern(success: false);
  }

  /// "Replay" on the wrong-move prompt: restart the whole level cleanly
  /// (pattern 1, mistakes reset, duel scores reset) without touching any
  /// unlocked-level progress.
  void replayLevel() {
    if (!_wrongPromptVisible) return;
    _wrongPromptVisible = false;
    _errorCell = null;
    _mistakes = 0;
    _foundCells = <int>{};
    _puzzle.restoreToPattern(0);
    if (_duel) {
      _player1Score = 0;
      _player2Score = 0;
      _currentPlayer = 1;
      _roundsPlayed = 0;
    }
    _beginPattern();
    onRestart();
  }

  /// Hint support. Reveals one cell of the current pattern (or explains
  /// why no reveal is possible) and returns the message for the shell.
  /// Called from the shell's hint flow — never during build.
  String? revealHintCell() {
    if (_disposed || _reported) return null;
    if (_phase != MemoryPhase.recall) {
      return 'Watch closely — the pattern is still showing.';
    }
    final cells = _puzzle.currentPatternCells;
    if (cells.isEmpty) return null;
    final cell = cells.first;
    _shown = {cell};
    notifyListeners();
    _runAfter(const Duration(milliseconds: 1200), () {
      if (_phase != MemoryPhase.recall) return;
      if (_shown.length == 1 && _shown.contains(cell)) {
        _shown = const <int>{};
        notifyListeners();
      }
    });
    return 'One cell of the pattern is flashing.';
  }

  // --- internals -----------------------------------------------------------

  /// The only place timers are created. Every callback is guarded by the
  /// [_disposed] flag, so a disposed controller can never notify anyone.
  void _runAfter(Duration duration, void Function() action) {
    final timer = Timer(duration, () {
      if (_disposed) return;
      action();
    });
    _timers.add(timer);
  }

  /// Input lock while a feedback animation runs. Rapid tapping during the
  /// tick/shake cannot race the state machine.
  void _lock(Duration duration) {
    _lockCount++;
    _runAfter(duration, () {
      _lockCount--;
      notifyListeners();
    });
  }

  /// Snapshot a just-finished round as a *stable* state.
  ///
  /// Deliberately does not notify: it runs between a state change and its
  /// report, and the notification that follows ([_endPattern] / the tap's
  /// own `notifyListeners`) reflects exactly this state. Its job is to
  /// make sure a save pulled in between (via `onMove`) records "pattern
  /// finished" rather than the transient pre-transition phase — otherwise
  /// resume could replay a pattern the player already cleared.
  void _freezeRound() {
    _phase = MemoryPhase.between;
    _shown = const <int>{};
  }

  void _beginPattern() {
    _phase = MemoryPhase.showing;
    _shown = _puzzle.currentPatternCells;
    _foundCells = <int>{};
    _errorCell = null;
    _wrongPromptVisible = false;
    _note = memorizeNote(duel: _duel, player: _currentPlayer);
    notifyListeners();

    final revealMs = (_duel ? 1600 : 1900 - _puzzle.patternCount * 90).clamp(
      900,
      1900,
    );
    _runAfter(Duration(milliseconds: revealMs), () {
      if (_reported) return;
      _phase = MemoryPhase.recall;
      _shown = const <int>{};
      _note = _duel
          ? 'Player $_currentPlayer — rebuild it'
          : 'Rebuild the pattern';
      notifyListeners();
    });
  }

  void _endPattern({required bool success}) {
    _phase = MemoryPhase.between;
    _shown = const <int>{};
    notifyListeners();

    if (_duel) {
      if (success) {
        if (_currentPlayer == 1) {
          _player1Score++;
        } else {
          _player2Score++;
        }
      }
      _roundsPlayed++;
      if (_roundsPlayed >= _duelRounds) {
        _finishDuel();
        return;
      }
      _note = "Player $_currentPlayer's turn";
      notifyListeners();
      _runAfter(const Duration(milliseconds: 700), () {
        _currentPlayer = _currentPlayer == 1 ? 2 : 1;
        _beginPattern();
      });
      return;
    }

    if (_puzzle.isFinished) {
      _reported = true;
      _phase = MemoryPhase.done;
      notifyListeners();
      onSolved(null, _puzzle.patternCount * _puzzle.cellsPerPattern);
      return;
    }
    _runAfter(const Duration(milliseconds: 700), _beginPattern);
  }

  void _finishDuel() {
    _reported = true;
    _phase = MemoryPhase.done;
    final summary = _player1Score == _player2Score
        ? "It's a draw — $_player1Score all."
        : 'Player ${_player1Score > _player2Score ? 1 : 2} wins '
              '$_player1Score–$_player2Score';
    _note = summary;
    notifyListeners();
    onSolved(summary, null);
  }

  /// Serialized in-progress state for the save/resume layer. Solo only —
  /// the 2-player duel is a fresh game every time. Null when there is
  /// nothing meaningful to restore.
  ///
  /// The saved phase is *faithful*: a save taken while the pattern is
  /// still revealing is restored as `showing`, so continuing a level never
  /// asks the player to rebuild a pattern they were never shown.
  Map<String, dynamic>? serializeProgress() {
    if (_disposed || _reported || _duel || _puzzle.isFinished) return null;
    // The saved phase is faithful on *both* sides of the transition:
    // `showing` and the frozen `between` beat (a round just finished, the
    // next pattern not yet dealt) both persist as "show" with no found
    // cells. The pattern at `currentPattern` has never been revealed to the
    // player in that state, so continuing must reveal it — never ask them
    // to rebuild a pattern they were never shown.
    final revealing =
        _phase == MemoryPhase.showing || _phase == MemoryPhase.between;
    return {
      'pattern': _puzzle.currentPattern,
      'mistakes': _mistakes,
      'found': revealing ? const <int>[] : _foundCells.toList(),
      'phase': revealing ? 'show' : 'recall',
    };
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    super.dispose();
  }
}
