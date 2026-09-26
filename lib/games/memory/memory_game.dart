import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import '../../core/models/game_definition.dart';
import '../../core/models/puzzle_session.dart';
import 'memory_controller.dart';

/// Memory — watch the pattern, then rebuild it from memory.
/// Also supports a local 2-player duel: alternate patterns, most wins.
class MemoryGame extends GameDefinition {
  @override
  String get id => 'memory';

  @override
  String get name => 'Memory';

  @override
  String get tagline => 'Watch. Remember. Rebuild.';

  @override
  String get instructions =>
      'A pattern flashes briefly. Tap the cells you remember. '
      'Reproduce every pattern to win.';

  @override
  List<String> get howItWorks => const [
        'A pattern of cells flashes briefly — memorize it.',
        'Then rebuild it from memory by tapping the cells.',
        'Reproduce every pattern to complete the level.',
  ];

  @override
  List<String> get howToPlay => const [
        'Watch the flashing pattern closely while it lasts.',
        'Tap the exact cells you remember — one wrong tap costs the round.',
        'Clear every pattern to finish the level.',
      ];

  @override
  IconData get icon => Icons.psychology_outlined;

  @override
  Color get accent => GameAccents.memory;

  @override
  int get totalLevels => 40;

  @override
  bool get supportsTwoPlayer => true;

  @override
  String? initialNoteFor(PuzzleSession session) => MemoryGameController.initialNote(
        level: session.level ?? 1,
        duel: session.mode == PuzzleMode.twoPlayer,
        saved: session.resume?.details,
      );

  @override
  PuzzleGameWidget createBoard(PuzzleSession session) =>
      MemoryBoard(session: session);
}

class MemoryBoard extends PuzzleGameWidget {
  const MemoryBoard({super.key, required super.session});

  @override
  State<MemoryBoard> createState() => _MemoryBoardState();
}

/// Thin view over [MemoryGameController].
///
/// `build()` is side-effect free: it only reads controller state. The
/// controller is created exactly once in `initState()` — never in
/// `build()` — so rebuilds can never re-initialize or re-shuffle the board.
/// The starting status line is seeded by the gameplay shell via
/// `GameDefinition.initialNoteFor` *before* this widget exists, so nothing
/// is emitted during initState (the old "setState during build" bug).
class _MemoryBoardState extends State<MemoryBoard> {
  MemoryGameController? _controller;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    final controller = MemoryGameController(
      level: session.level ?? 1,
      seed: session.seed,
      duel: session.mode == PuzzleMode.twoPlayer,
      saved: session.resume?.details,
      onMove: session.host.move,
      onInvalidMove: (countsAsFailure) =>
          session.host.invalidMove(countsAsFailure: countsAsFailure),
      onSolved: (summary, optimalMoves) =>
          session.host.solve(summary: summary, optimalMoves: optimalMoves),
      onRestart: session.host.onLevelRestarted,
      onMatch: session.host.playMatchFeedback,
    );
    controller.addListener(_handleControllerChanged);
    _controller = controller;
    session.hintBridge.register(_revealHint);
    session.progressBridge.register(_snapshotProgress);
  }

  @override
  void dispose() {
    widget.session.hintBridge.unregister(_revealHint);
    widget.session.progressBridge.unregister(_snapshotProgress);
    _controller?.removeListener(_handleControllerChanged);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  /// Serialized in-progress state for the save/resume layer. Pulled by the
  /// gameplay shell on back / dispose / app backgrounded.
  Map<String, dynamic>? _snapshotProgress() =>
      _controller?.serializeProgress();

  /// Single channel from game state → widget tree. The controller only
  /// notifies from timers and tap callbacks — always outside the build
  /// phase — so this setState is always legal. The note line is forwarded
  /// to the shell here too (never synchronously during a build).
  void _handleControllerChanged() {
    if (!mounted) return;
    setState(() {});
    final note = _controller?.note;
    if (note != null && widget.session.note.value != note) {
      widget.session.note.emit(note);
    }
  }

  PuzzleHint? _revealHint() {
    final message = _controller?.revealHintCell();
    if (message == null) return null;
    return PuzzleHint(message);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final accent = widget.session.game.accent;
    final colors = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.isDuel)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.space4),
              child: _DuelScoreboard(
                player1: controller.player1Score,
                player2: controller.player2Score,
                currentPlayer: controller.currentPlayer,
                accent: accent,
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              // Reserve space for the wrong-move prompt so the grid never
              // overflows when it appears.
              final promptSpace = controller.wrongPromptVisible ? 64.0 : 0.0;
              final side = math.min(constraints.maxWidth,
                      math.max(0.0, constraints.maxHeight - promptSpace))
                  .toDouble();
              return SizedBox(
                width: side,
                height: side,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: controller.puzzle.size,
                    mainAxisSpacing: AppDimens.space2,
                    crossAxisSpacing: AppDimens.space2,
                  ),
                  itemCount: controller.puzzle.size * controller.puzzle.size,
                  itemBuilder: (context, index) {
                    final revealed = controller.phase == MemoryPhase.showing &&
                        controller.shownCells.contains(index);
                    return MemoryCell(
                      key: ValueKey('memory-cell-$index'),
                      revealed: revealed,
                      found: controller.foundCells.contains(index),
                      error: controller.errorCell == index,
                      errorStamp: controller.errorStamp,
                      active: controller.interactive,
                      accent: accent,
                      onTap: () => controller.tap(index),
                    );
                  },
                ),
              );
            },
          ),
          if (controller.wrongPromptVisible)
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.space3),
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.space3,
                  AppDimens.space1,
                  AppDimens.space1,
                  AppDimens.space1,
                ),
                decoration: BoxDecoration(
                  color: GameAccents.tint(context, colors.error, alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                  border: Border.all(
                    color: colors.error.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: colors.error),
                    const SizedBox(width: AppDimens.space2),
                    Expanded(
                      child: Text(
                        'Wrong move',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    TextActionButton(
                      label: 'Replay',
                      color: colors.error,
                      onPressed: controller.replayLevel,
                    ),
                    TextActionButton(
                      label: 'Try again',
                      onPressed: controller.tryAgain,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One Memory tile. Shared by the solo/duel board and the nearby duel
/// screen so every mode renders identically.
///
/// [revealed] — pattern cell flashing during the show phase.
/// [found] — correctly tapped cell, stays lit with a tick.
/// [error] + [errorStamp] — wrong tap: cross + subtle shake per stamp.
class MemoryCell extends StatelessWidget {
  const MemoryCell({
    super.key,
    required this.revealed,
    required this.found,
    required this.error,
    required this.errorStamp,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  /// Pattern cell flashing during the "show" phase.
  final bool revealed;

  /// Correctly tapped cell — stays lit with a tick for the whole round.
  final bool found;

  /// Just-tapped incorrect cell — cross + subtle shake.
  final bool error;
  final int errorStamp;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lit = revealed || found;
    final background = error
        ? GameAccents.tint(context, colors.error, alpha: 0.14)
        : found
            ? GameAccents.tint(context, accent, alpha: 0.22)
            : revealed
                ? accent
                : colors.surfaceAlt;
    final borderColor = error
        ? colors.error
        : lit
            ? accent
            : colors.border;
    final icon = error
        ? Icons.close_rounded
        : found
            ? Icons.check_rounded
            : null;
    final iconColor = error ? colors.error : accent;

    Widget cell = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
        border: Border.all(color: borderColor, width: error ? 1.5 : 1),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1.0).animate(animation),
              child: child,
            ),
          ),
          child: icon != null
              ? Icon(
                  key: ValueKey(icon),
                  icon,
                  size: 18,
                  color: iconColor,
                )
              : const SizedBox.shrink(key: ValueKey('cell-empty')),
        ),
      ),
    );

    if (error) {
      // Subtle shake, restarted for every new mistake via the stamp key.
      cell = TweenAnimationBuilder<double>(
        key: ValueKey('shake-$errorStamp'),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        builder: (context, t, child) {
          final decay = 1 - t;
          final dx = math.sin(t * math.pi * 4) * 5 * decay;
          return Transform.translate(offset: Offset(dx, 0), child: child!);
        },
        child: cell,
      );
    }

    return GestureDetector(
      onTap: active ? onTap : null,
      child: cell,
    );
  }
}

class _DuelScoreboard extends StatelessWidget {
  const _DuelScoreboard({
    required this.player1,
    required this.player2,
    required this.currentPlayer,
    required this.accent,
  });

  final int player1;
  final int player2;
  final int currentPlayer;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget side(String label, int score, bool active) {
      return AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: active ? 1 : 0.45,
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
                color: active ? accent : colors.textTertiary,
              ),
            ),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: active ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        side('Player 1', player1, currentPlayer == 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.space5),
          child: Text(
            'VS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: colors.textTertiary,
            ),
          ),
        ),
        side('Player 2', player2, currentPlayer == 2),
      ],
    );
  }
}
