import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/models/puzzle_session.dart';
import '../../core/services/game_state_service.dart';
import '../../core/services/service_scope.dart';

/// The shared gameplay shell.
///
/// Owns everything common to every puzzle: header, move/time counters,
/// hint + reset controls, completion flow, quiet failure support and the
/// rewarded-ad exchange. A game only provides its board.
///
/// Save/resume: the shell persists moves + elapsed time + the board's
/// progress snapshot (via `session.progressBridge`) on every move, on
/// dispose (back) and when the app is backgrounded — so leaving mid-level
/// never resets it. Completing a level clears the saved state.
class GameplayScreen extends StatefulWidget {
  const GameplayScreen({super.key, required this.session});

  final PuzzleSession session;

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen>
    with WidgetsBindingObserver {
  AppServices? _servicesCache;
  AppServices get _services => _servicesCache ??= ServiceScope.of(context);

  PuzzleSession get _session => widget.session;

  /// Live counters. Kept in [ValueNotifier]s so a move or a once-per-second
  /// timer tick repaints only the tiny stats row — never the board subtree,
  /// which is the most expensive part of the screen.
  final ValueNotifier<int> _moves = ValueNotifier<int>(0);
  final ValueNotifier<int> _seconds = ValueNotifier<int>(0);
  late final Listenable _stats = Listenable.merge([_moves, _seconds]);

  int _failedAttempts = 0;
  bool _solved = false;
  bool _completionHandled = false;
  bool _showingStuckSheet = false;

  String? _note;
  PuzzleHint? _hint;
  Timer? _hintTimer;
  Timer? _stopwatch;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final session = _session;
    // Restore in-progress state ("Continue your game?" flow). The board
    // reads session.resume in its own initState.
    final resume = session.resume;
    if (resume != null) {
      _moves.value = resume.moves;
      _seconds.value = resume.seconds;
    }

    // Seed the session's starting status line *before* the board exists.
    // Boards must never emit during their own initState, which runs while
    // this screen is building — that was the source of the
    // "setState() or markNeedsBuild() called during build" error.
    _note = session.game.initialNoteFor(session);
    session.note.seed(_note);
    // `this` is the binding owner: a replaced screen's dispose() can then
    // never detach the replacement's listener/callbacks.
    session.note.listen(this, _onNote);
    session.hintBridge.register(_provideHint);
    session.host.bind(
      this,
      onMove: _onMove,
      onInvalidMove: (countsAsFailure) =>
          _onInvalidMove(countsAsFailure: countsAsFailure),
      onSolve: (summary, optimalMoves) =>
          _onSolve(summary: summary, optimalMoves: optimalMoves),
      onSupport: _onSupportRequested,
      onLevelRestarted: _onLevelRestarted,
      onSlideFeedback: () {
        _services.haptics.slide();
        _services.audio.slide();
      },
      onFlipFeedback: () {
        _services.haptics.flip();
        _services.audio.flip();
      },
      onMatchFeedback: () {
        _services.haptics.cellMatch();
        _services.audio.match();
      },
    );

    // Resume with a running timer when there was progress to restore.
    if (_moves.value > 0 || _seconds.value > 0) _startTimer();
  }

  bool _staleSaveCleared = false;
  bool _nudgeDecided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cached here (not initState) — inheriting widgets must be depended on
    // after initState completes. The scope sits above MaterialApp and never
    // changes, so a single cache is enough.
    _servicesCache ??= ServiceScope.of(context);

    // First-move nudge for brand-new players: fresh level 1 of a game,
    // and the player has never completed any level anywhere. Decided
    // once, after the first frame's dependencies are available.
    if (!_nudgeDecided) {
      _nudgeDecided = true;
      final session = _session;
      if (session.mode == PuzzleMode.solo &&
          session.level == 1 &&
          session.resume == null &&
          _services.progress.totalSolved == 0) {
        session.firstMoveNudgeText = session.game.firstMoveNudge(session);
        session.firstMoveNudgeCell = session.game.nudgeCellIndex(session);
      }
    }

    // Starting fresh clears any stale save for this level — the player
    // explicitly chose a new attempt over "Continue". Runs exactly once.
    // The storage write notifies listeners, so it is deferred to a
    // post-frame callback: didChangeDependencies runs during build, and
    // notifying the ServiceScope here would throw
    // "setState() or markNeedsBuild() called during build".
    if (!_staleSaveCleared) {
      _staleSaveCleared = true;
      final session = _session;
      if (session.level != null &&
          !session.isDaily &&
          session.mode == PuzzleMode.solo &&
          session.resume == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            _services.gameStates.clearGameState(
              session.game.id,
              session.level!,
            ),
          );
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding (and the transient states around it) must never lose
    // the current level.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _saveProgress();
    }
  }

  @override
  void dispose() {
    // Note: back-navigation saves happen in `onPopInvokedWithResult` below,
    // not here. Flutter unmounts children before parents, so by the time
    // this runs the board is already disposed and its progress snapshot is
    // gone — a save here would silently do nothing. Kept as a last-resort
    // fallback (a no-op when no snapshot is available).
    _saveProgress();
    WidgetsBinding.instance.removeObserver(this);
    _stopwatch?.cancel();
    _hintTimer?.cancel();
    _completionTimer?.cancel();
    _session.note.removeListener(this);
    _session.hintBridge.unregister(_provideHint);
    _session.host.unbind(this);
    _moves.dispose();
    _seconds.dispose();
    super.dispose();
  }

  // --- PuzzleHost ---------------------------------------------------------

  void _onMove() {
    if (_solved) return;
    // The nudge has done its job the moment the player acts.
    _session.firstMoveNudgeText = null;
    _session.firstMoveNudgeCell = null;
    if (_moves.value == 0) _startTimer();
    // No setState: the counters are owned by ValueNotifiers, so an ordinary
    // move only repaints the stats row (the board repaints itself).
    _moves.value++;
    _services.haptics.tap();
    _saveProgress();
  }

  void _onInvalidMove({bool countsAsFailure = false}) {
    if (_solved) return;
    _services.haptics.warning();
    if (!countsAsFailure) return;
    _failedAttempts++;
    _saveProgress();
    if (_failedAttempts == 3 && !_showingStuckSheet) {
      _showingStuckSheet = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showStillStuckSheet(),
      );
    }
  }

  void _onLevelRestarted() {
    // The board replayed itself from the wrong-move prompt: reset the
    // shell counters and drop the stale saved attempt.
    _stopwatch?.cancel();
    if (!mounted) return;
    _moves.value = 0;
    _seconds.value = 0;
    final session = _session;
    if (session.level != null) {
      // Sync: the Restart that follows this must not race the clear.
      _services.gameStates.clearGameStateSync(session.game.id, session.level!);
    }
  }

  /// Persists the current level for the "Continue your game?" flow.
  /// Solo levels only — the daily challenge and the 2-player duel are
  /// self-contained. Saved only once there is something to restore.
  void _saveProgress() {
    if (_solved || !mounted) return;
    final session = _session;
    if (session.isDaily || session.level == null) return;
    if (session.mode != PuzzleMode.solo) return;
    if (_moves.value == 0 && _seconds.value == 0) return;
    final details = session.progressBridge.snapshot();
    if (details == null) return;
    // Sync path: this runs from `onPopInvokedWithResult`/`dispose`/the
    // lifecycle observer, where an await could be dropped. The write is
    // cached in memory immediately and dispatched to disk at once.
    _services.gameStates.saveGameStateSync(
      SavedGameState(
        gameId: session.game.id,
        level: session.level!,
        moves: _moves.value,
        seconds: _seconds.value,
        details: details,
        savedAt: DateTime.now(),
      ),
    );
  }

  void _onSolve({String? summary, int? optimalMoves}) {
    if (_solved) return;
    _solved = true;
    _stopwatch?.cancel();
    _services.haptics.success();
    _services.audio.success();
    // Completion sheet appears after a short satisfying beat — the board
    // gets a moment to show its own "done" state first. An owned Timer
    // (not Future.delayed) so leaving the screen cancels it instead of
    // letting a callback outlive the widget.
    _completionTimer?.cancel();
    _completionTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      _showCompletion(summary: summary, optimalMoves: optimalMoves);
    });
  }

  void _onNote(String? note) {
    if (!mounted || _note == note) return;
    setState(() => _note = note);
  }

  /// The board judges the player genuinely stuck. Offer help exactly
  /// once, quietly — never automatically, never an ad.
  void _onSupportRequested() {
    if (_solved || _showingStuckSheet || _completionHandled) return;
    _showingStuckSheet = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showStillStuckSheet());
  }

  PuzzleHint? _provideHint() => _hint;

  void _startTimer() {
    _stopwatch = Timer.periodic(const Duration(seconds: 1), (_) {
      // Ticks only the TIME readout; no setState, no board rebuild.
      if (mounted && !_solved) _seconds.value++;
    });
  }

  // --- Completion ----------------------------------------------------------

  Future<void> _showCompletion({String? summary, int? optimalMoves}) async {
    if (_completionHandled) return;
    _completionHandled = true;

    final session = _session;
    final services = _services;

    // Persist.
    if (session.isDaily) {
      await services.daily.completeToday(
        DateTime.now(),
        gameId: session.game.id,
        moves: _moves.value,
        seconds: _seconds.value,
      );
    } else if (session.level != null) {
      // Completing a level clears its unfinished state — a completed
      // level must never be offered as "Continue your game?". Sync so
      // the clear is visible to the screen we are about to navigate to.
      services.gameStates.clearGameStateSync(session.game.id, session.level!);
      services.progress.recordLevelResult(
        session.game,
        level: session.level!,
        moves: _moves.value,
        seconds: _seconds.value,
        perfect: optimalMoves != null && _moves.value <= optimalMoves,
      );
    } else {
      services.progress.markLastPlayed(session.game, 1);
    }

    if (!mounted) return;
    final nextLevel = session.isDaily || session.level == null
        ? null
        : (session.level! < session.game.totalLevels
              ? session.level! + 1
              : null);

    // Celebrate a flawless solve — the data is already tracked, it just
    // was never shown. Only for level play (daily/duel summaries already
    // carry their own line).
    String? badge;
    if (optimalMoves != null && _moves.value <= optimalMoves && !session.isDaily) {
      badge = 'Perfect — only $optimalMoves moves';
    }

    await showAppSheet(
      context: context,
      isDismissible: false,
      builder: (sheetContext) => GameCompletionSheet(
        accent: session.game.accent,
        data: CompletionData(
          title: session.isDaily
              ? 'Daily complete'
              : 'Level ${session.level ?? 1}',
          note: summary,
          badge: badge,
          stats: [
            ('Moves', '${_moves.value}'),
            ('Time', '${_seconds.value}s'),
          ],
          primaryLabel: nextLevel != null ? 'Next Level' : 'Done',
          secondaryLabel: 'Replay',
        ),
        onPrimary: () {
          Navigator.pop(sheetContext);
          if (nextLevel != null) {
            AppRouter.replaceGameplay(
              context,
              PuzzleSession(
                game: session.game,
                level: nextLevel,
                seed: session.game.seedForLevel(nextLevel),
              ),
            );
          } else {
            AppRouter.pop(context);
          }
        },
        onSecondary: () {
          Navigator.pop(sheetContext);
          // Replay the level fresh — never resume the just-completed
          // attempt's saved state (it was cleared above).
          AppRouter.replaceGameplay(context, session.withoutResume());
        },
      ),
    );
  }

  // --- Restart --------------------------------------------------------------

  /// Reset button: a small confirmation, since a restart throws away the
  /// in-level progress (unlocked levels are never touched).
  void _confirmRestart() {
    showAppSheet(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          SheetBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.space5),
                Text(
                  'Restart this level?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppDimens.space1),
                Text(
                  'Progress within this level is lost. '
                  'Unlocked levels are kept.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppDimens.space6),
                PrimaryButton(
                  label: 'Restart',
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _restartLevel();
                  },
                ),
                TextActionButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Restores the level's initial state and clears its unfinished save —
  /// but never touches unlocked-level progress.
  void _restartLevel() {
    final session = _session;
    if (session.level != null) {
      // Sync: the clear must be durable *before* the replacement screen
      // mounts, or an async clear could land after the new attempt has
      // already written its own first save and delete it.
      _services.gameStates.clearGameStateSync(session.game.id, session.level!);
    }
    AppRouter.replaceGameplay(context, session.withoutResume());
  }

  // --- Hints & menu --------------------------------------------------------

  Future<void> _onHintPressed() async {
    final services = _services;
    final game = _session.game;
    final levelKey = _session.level ?? 0;

    if (!services.hints.canShowHint(game.id, levelKey)) {
      _toast('No hints left for this level.');
      return;
    }

    final wantsHint = await showAppSheet<bool>(
      context: context,
      builder: (sheetContext) => RewardedHintSheet(
        accent: game.accent,
        hintsRemaining:
            HintServiceLimits.maxHintsPerLevel -
            services.hints.hintsUsedFor(game.id, levelKey),
        onWatchAd: () => Navigator.pop(sheetContext, true),
        onNotNow: () => Navigator.pop(sheetContext, false),
      ),
    );
    if (wantsHint != true || !mounted) return;

    final earned = await services.hints.earnHint(game.id, levelKey);
    if (!mounted) return;
    if (!earned) {
      _toast('Hint not available right now.');
      return;
    }

    final hint = _session.hintBridge.request();
    if (!mounted) return;
    if (hint == null) {
      _toast('No hint available for this puzzle yet.');
      return;
    }
    setState(() => _hint = hint);
    _hintTimer?.cancel();
    _hintTimer = Timer(hint.displayFor, () {
      if (mounted) setState(() => _hint = null);
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.colors.primary,
        content: Text(
          message,
          style: TextStyle(color: context.colors.onPrimary),
        ),
      ),
    );
  }

  void _showStillStuckSheet() {
    showAppSheet(
      context: context,
      builder: (sheetContext) => StillStuckSheet(
        accent: _session.game.accent,
        onGetHint: () {
          Navigator.pop(sheetContext);
          _onHintPressed();
        },
        onKeepTrying: () => Navigator.pop(sheetContext),
      ),
    ).whenComplete(() => _showingStuckSheet = false);
  }

  void _showMenu() {
    final game = _session.game;
    showAppSheet(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetHandle(),
          SheetBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimens.space5),
                Text(game.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppDimens.space4),
                SecondaryButton(
                  label: 'How to play',
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showHowToPlay();
                  },
                ),
                const SizedBox(height: AppDimens.space2),
                SecondaryButton(
                  label: 'Restart level',
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _restartLevel();
                  },
                ),
                const SizedBox(height: AppDimens.space2),
                SecondaryButton(
                  label: 'Leave level',
                  onPressed: () => AppRouter.pop(sheetContext),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHowToPlay() {
    final game = _session.game;
    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HowToPlaySheet(
        gameName: game.name,
        howItWorks: game.howItWorks,
        howToPlay: game.howToPlay,
        accent: game.accent,
      ),
    );
  }

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final showTimer = !_session.isDaily;

    // Back (button or system gesture) is a *save point*: leaving mid-level
    // must never lose the attempt. `onPopInvokedWithResult` fires while the
    // board is still alive, unlike this screen's dispose — which is why the
    // save lives here and not in dispose().
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveProgress();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Column(
            children: [
              GameHeader(
                label: _session.headerLabel,
                sublabel: _session.headerSublabel,
                onBack: () => AppRouter.pop(context),
                onMenu: _showMenu,
              ),
              // Only this row listens to the counters: a move or a timer
              // tick repaints two small Text widgets, not the board.
              AnimatedBuilder(
                animation: _stats,
                builder: (context, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _QuietStat(label: 'MOVES', value: '${_moves.value}'),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.space4,
                      ),
                      child: Container(
                        width: 1,
                        height: 20,
                        color: colors.border,
                      ),
                    ),
                    _QuietStat(
                      label: 'TIME',
                      value: showTimer ? '${_seconds.value} s' : '—',
                    ),
                  ],
                ),
              ),
              if (_hint != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.pagePadding,
                    AppDimens.space2,
                    AppDimens.pagePadding,
                    0,
                  ),
                  child: InlineBanner(
                    message: _hint!.message,
                    accent: _session.game.accent,
                  ),
                )
              else if (_note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.pagePadding,
                    AppDimens.space2,
                    AppDimens.pagePadding,
                    0,
                  ),
                  child: Text(
                    _note!,
                    style: TextStyle(fontSize: 12, color: colors.textTertiary),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimens.space4),
                  child: KeyedSubtree(
                    key: ValueKey(
                      '${_session.game.id}-${_session.level}-'
                      '${_session.seed}-${_session.isDaily}-${_session.mode.name}',
                    ),
                    child: _session.game.createBoard(_session),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppDimens.space4,
                  0,
                  AppDimens.space4,
                  MediaQuery.paddingOf(context).bottom + AppDimens.space4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: HintButton(
                        label: 'Hint',
                        accent: _session.game.accent,
                        onPressed: _onHintPressed,
                      ),
                    ),
                    const SizedBox(width: AppDimens.space3),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Reset',
                        onPressed: _confirmRestart,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietStat extends StatelessWidget {
  const _QuietStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: colors.textTertiary,
          ),
        ),
      ],
    );
  }
}
