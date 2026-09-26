import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import '../../core/models/game_definition.dart';
import '../../core/models/puzzle_session.dart';
import '../../core/services/service_scope.dart';
import 'shift_puzzle.dart';

/// Shift — slide the tiles into order. Tap a tile next to the gap.
class ShiftGame extends GameDefinition {
  @override
  String get id => 'shift';

  @override
  String get name => 'Shift';

  @override
  String get tagline => 'Order from chaos. Slide the tiles.';

  @override
  String get instructions =>
      'Tap a tile next to the empty space to slide it. '
      'Restore the natural order to win.';

  @override
  List<String> get howItWorks => const [
    'There is one empty space on the board.',
    'Tap any tile touching the empty space to slide it in.',
    'Restore every tile to its natural order to win.',
  ];

  @override
  List<String> get howToPlay => const [
    'Tap a tile directly next to the empty space to slide it there.',
    'The empty space moves to where the tile was — keep chasing it.',
    'Order the tiles 1, 2, 3… to complete the level.',
  ];

  @override
  String? firstMoveNudge(PuzzleSession session) =>
      'Tap the tile next to the empty space — watch where the gap goes.';

  @override
  int? nudgeCellIndex(PuzzleSession session) {
    // Only for a completely fresh level 1.
    if (session.level != 1 || session.resume != null) return null;
    final saved = session.resume;
    if (saved != null) return null;
    final puzzle = ShiftPuzzle(level: 1, seed: session.seed);
    // A tile adjacent to the gap is always a legal, sensible first tap.
    final gap = puzzle.tiles.indexOf(0);
    final gapRow = gap ~/ puzzle.size;
    final gapCol = gap % puzzle.size;
    for (final (dr, dc) in const [(0, 1), (1, 0), (0, -1), (-1, 0)]) {
      final r = gapRow + dr;
      final c = gapCol + dc;
      if (r >= 0 && r < puzzle.size && c >= 0 && c < puzzle.size) {
        return r * puzzle.size + c;
      }
    }
    return null;
  }

  @override
  IconData get icon => Icons.grid_view_outlined;

  @override
  Color get accent => GameAccents.shift;

  @override
  int get totalLevels => 40;

  @override
  PuzzleGameWidget createBoard(PuzzleSession session) =>
      ShiftBoard(session: session);
}

class ShiftBoard extends PuzzleGameWidget {
  const ShiftBoard({super.key, required super.session});

  @override
  State<ShiftBoard> createState() => _ShiftBoardState();
}

class _ShiftBoardState extends State<ShiftBoard> {
  late final ShiftPuzzle _puzzle;
  late List<int> _board;
  late List<int> _initialBoard;
  int? _hintIndex;
  int? _avoidIndex;
  bool _reported = false;
  int _lastMoved = -1;

  /// Owned timers, cancelled in [dispose] so no callback outlives the board.
  Timer? _hintClearTimer;
  Timer? _moveTimer;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    // Save/resume: restore the exact tile arrangement the player left,
    // never reshuffled.
    final saved = session.resume?.details;
    _puzzle =
        ShiftPuzzle.fromSerialized(saved ?? const {}) ??
        ShiftPuzzle(level: session.level ?? 1, seed: session.seed);
    _board = [..._puzzle.tiles];
    _initialBoard = [
      if (saved?['initial'] is List)
        for (final tile in (saved!['initial'] as List)) (tile as num).toInt()
      else
        ..._puzzle.tiles,
    ];
    _avoidIndex = (saved?['avoid'] as num?)?.toInt();
    widget.session.hintBridge.register(_revealHint);
    widget.session.progressBridge.register(_snapshotProgress);
  }

  @override
  void dispose() {
    _hintClearTimer?.cancel();
    _moveTimer?.cancel();
    widget.session.hintBridge.unregister(_revealHint);
    widget.session.progressBridge.unregister(_snapshotProgress);
    super.dispose();
  }

  /// Serialized in-progress state for the save/resume layer — only once
  /// the player has actually moved a tile.
  Map<String, dynamic>? _snapshotProgress() {
    if (_reported) return null;
    if (_board.join(',') == _initialBoard.join(',')) return null;
    return {
      ..._puzzle.serialize(),
      'initial': _initialBoard,
      'avoid': _avoidIndex,
    };
  }

  PuzzleHint? _revealHint() {
    final index = _puzzle.solveNextMoveIndex(_board, avoidIndex: _avoidIndex);
    if (index == null) return null;
    setState(() => _hintIndex = index);
    _hintClearTimer?.cancel();
    _hintClearTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _hintIndex = null);
    });
    return PuzzleHint('Slide the highlighted tile.');
  }

  void _tapTile(int index) {
    if (_reported) return;
    if (!_puzzle.canSlide(_board, index)) {
      // Gentle feedback: the tile cannot move.
      widget.session.host.invalidMove();
      return;
    }
    setState(() {
      _avoidIndex = _board.indexOf(0); // reversal tile after this move
      _board = _puzzle.slide(_board, index);
      _hintIndex = null;
      _lastMoved = _avoidIndex!;
    });

    // The arrangement above is final for this move. Detect completion
    // before reporting the move, so the snapshot the shell takes inside
    // `host.move()` can never be a solved board that still claims to be
    // unfinished (resuming that would strand the level).
    final justSolved = _puzzle.isSolved(_board);
    if (justSolved) _reported = true;
    widget.session.host.move();
    widget.session.host.playSlideFeedback();

    if (justSolved) {
      // Perfect-solve tracking only when the optimal length is cheaply
      // provable (bounded search); otherwise no perfect badge.
      final optimal = _optimalLengthWithinBudget();
      widget.session.host.solve(optimalMoves: optimal);
    }
  }

  int? _optimalLengthWithinBudget() {
    final solution = _puzzle.pathWithinDepth(_initialBoard, nodeBudget: 120000);
    return solution?.length;
  }

  /// One [AnimatedPositioned] per tile, keyed by the tile's id so the same
  /// widget instance animates between slots. Tap targets track the tile's
  /// CURRENT slot: the GestureDetector wraps the AnimatedPositioned child,
  /// and AnimatedPositioned updates its child's position each frame of the
  /// animation.
  Widget _buildTileWidget(
    BuildContext context, {
    required int tile,
    required double cell,
    required double gap,
    required double Function(int) offset,
    required Color accent,
  }) {
    final index = _board.indexOf(tile);
    final nudgeCell = widget.session.firstMoveNudgeCell;
    final showGoal = (widget.session.level ?? 1) <= 3;
    final services = ServiceScope.of(context);
    final row = index ~/ _puzzle.size;
    final col = index % _puzzle.size;
    final inPosition = showGoal && tile == index + 1;
    final isHint = _hintIndex == index || (nudgeCell != null && nudgeCell == index);

    return AnimatedPositioned(
      key: ValueKey('shift-tile-$tile'),
      left: offset(col),
      top: offset(row),
      width: cell,
      height: cell,
      // motion() already collapses to ~1ms when reduced-motion is on.
      duration: services.settings.motion(150),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTap: () => _tapTile(index),
        child: _ShiftTile(
          label: '$tile',
          isHint: isHint,
          justMoved: _lastMoved == index,
          inPosition: inPosition,
          accent: accent,
          onTap: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.session.game.accent;
    final nudgeCell = widget.session.firstMoveNudgeCell;
    final showGoal = (widget.session.level ?? 1) <= 3;
    final nudgeText = widget.session.firstMoveNudgeText;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (nudgeText != null && nudgeCell != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.space3),
              child: Text(
                nudgeText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
            ),          LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth
                  .clamp(0.0, constraints.maxHeight)
                  .toDouble();
              // Tile size accounting for the gaps between tiles.
              final gap = AppDimens.space2.toDouble();
              final cell = (side - gap * (_puzzle.size - 1)) / _puzzle.size;
              double offset(int index) => index * (cell + gap);

              // One widget per tile, keyed by tile id (not slot): the tile
              // that slides into the gap keeps its widget, so
              // AnimatedPositioned animates it across the board — a real
              // slide, not a teleport.
              return SizedBox(
                width: side,
                height: side,
                child: Stack(
                  children: [
                    for (var index = 0; index < _board.length; index++)
                      if (_board[index] == 0)
                        Positioned(
                          left: offset(index % _puzzle.size),
                          top: offset(index ~/ _puzzle.size),
                          width: cell,
                          height: cell,
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  colors.surfaceAlt.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusSmall,
                              ),
                              border: Border.all(
                                color: colors.border,
                                width: 0.8,
                              ),
                            ),
                          ),
                        ),
                    for (final tile in _board)
                      if (tile != 0)
                        _buildTileWidget(
                          context,
                          tile: tile,
                          cell: cell,
                          gap: gap,
                          offset: offset,
                          accent: accent,
                        ),
                  ],
                ),
              );
            },
          ),
          if (showGoal)
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.space3),
              child: Text(
                'GOAL · 1 → ${_puzzle.size * _puzzle.size - 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.6,
                  color: colors.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShiftTile extends StatelessWidget {
  const _ShiftTile({
    required this.label,
    required this.isHint,
    required this.justMoved,
    required this.inPosition,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool isHint;
  final bool justMoved;

  /// Tile already sits in its final slot — a quiet tick replaces the
  /// number, teaching the goal state wordlessly.
  final bool inPosition;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: justMoved ? 1.0 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: justMoved
                ? GameAccents.tint(context, accent, alpha: 0.2)
                : colors.surface,
            borderRadius: BorderRadius.circular(AppDimens.radiusSmall),
            border: Border.all(
              color: isHint ? accent : colors.border,
              width: isHint ? 2 : 1,
            ),
            boxShadow: isHint
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: inPosition
                    ? accent.withValues(alpha: 0.9)
                    : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
