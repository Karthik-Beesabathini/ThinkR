import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../core/models/game_definition.dart';
import '../../core/models/puzzle_session.dart';
import 'lights_puzzle.dart';
import 'lights_tile.dart';

/// Lights — turn every light off. Tap = flip a tile and its neighbors.
class LightsGame extends GameDefinition {
  @override
  String get id => 'lights';

  @override
  String get name => 'Lights';

  @override
  String get tagline => 'Turn every light off.';

  @override
  String get instructions =>
      'Tap a tile to switch it and its neighbors on or off. '
      'Turn every light off to win.';

  @override
  List<String> get howItWorks => const [
    'Tap a bulb to switch it ON or OFF.',
    'The bulbs directly next to it switch too.',
    'Turn every bulb OFF to complete the level.',
  ];

  @override
  List<String> get howToPlay => const [
    'Tap any bulb to switch its state.',
    'The bulbs directly above, below, left, and right switch with it.',
    'Turn every bulb OFF using as few moves as possible.',
  ];

  @override
  IconData get icon => Icons.light_mode_outlined;

  @override
  Color get accent => GameAccents.lights;

  @override
  int get totalLevels => 60;

  @override
  String? firstMoveNudge(PuzzleSession session) =>
      'Tap any lit tile — it and its neighbors flip together.';

  @override
  int? nudgeCellIndex(PuzzleSession session) {
    if (session.level != 1 || session.resume != null) return null;
    final puzzle = LightsPuzzle(level: 1, seed: session.seed);
    for (var r = 0; r < puzzle.size; r++) {
      for (var c = 0; c < puzzle.size; c++) {
        if (puzzle.lights[r][c]) return r * puzzle.size + c;
      }
    }
    return null;
  }

  @override
  PuzzleGameWidget createBoard(PuzzleSession session) =>
      LightsBoard(session: session);
}

class LightsBoard extends PuzzleGameWidget {
  const LightsBoard({super.key, required super.session});

  @override
  State<LightsBoard> createState() => _LightsBoardState();
}

class _LightsBoardState extends State<LightsBoard>
    with SingleTickerProviderStateMixin {
  late final LightsPuzzle _puzzle;
  late final AnimationController _pulse;

  LightCell? _hintCell;
  bool _celebrating = false;
  int _presses = 0;
  bool _supportRequested = false;

  /// Owned timers, cancelled in [dispose]: a `Future.delayed` cannot be
  /// cancelled, so a callback could outlive the board after leaving the
  /// screen.
  Timer? _hintClearTimer;
  Timer? _solveTimer;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    // Save/resume: rebuild the exact board the player left, never
    // reshuffled. Falls back to the deterministic generated level.
    _puzzle =
        LightsPuzzle.fromSerialized(session.resume?.details ?? const {}) ??
        LightsPuzzle(level: session.level ?? 1, seed: session.seed);
    _presses = (session.resume?.details['presses'] as num?)?.toInt() ?? 0;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    session.hintBridge.register(_revealHint);
    session.progressBridge.register(_snapshotProgress);
  }

  @override
  void dispose() {
    _hintClearTimer?.cancel();
    _solveTimer?.cancel();
    _pulse.dispose();
    widget.session.hintBridge.unregister(_revealHint);
    widget.session.progressBridge.unregister(_snapshotProgress);
    super.dispose();
  }

  /// Serialized in-progress state for the save/resume layer — only after
  /// the player has actually interacted with the board.
  Map<String, dynamic>? _snapshotProgress() {
    if (_celebrating || _presses == 0) return null;
    return {..._puzzle.serialize(), 'presses': _presses};
  }

  PuzzleHint? _revealHint() {
    if (!_puzzle.hasHint) return null;
    final cell = _puzzle.hintCell();
    setState(() => _hintCell = cell);
    _hintClearTimer?.cancel();
    _hintClearTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _hintCell = null);
    });
    return PuzzleHint('Try row ${cell.r + 1}, column ${cell.c + 1}.');
  }

  void _press(LightCell cell) {
    if (_solved || _celebrating) return;
    // Apply the press *before* reporting the move: the shell snapshots
    // the board inside `host.move()` for save/resume, so the tapped state
    // must already be visible or a resumed board would forget a move.
    setState(() {
      _puzzle.press(cell);
      _hintCell = null;
    });
    _presses++;

    // Same snapshot rule as Shift: mark completion before reporting the
    // move, so the save pulled inside `host.move()` is never a solved
    // board masquerading as an unfinished level.
    final justSolved = _puzzle.isSolved;
    if (justSolved) _celebrating = true;

    widget.session.host.move();
    widget.session.host.playFlipFeedback();
    // Never offered on a level that is already finished.
    if (!justSolved &&
        !_supportRequested &&
        _presses > _puzzle.optimalMoves * 2 + _puzzle.size * 2) {
      _supportRequested = true;
      widget.session.host.requestSupport();
    }

    if (justSolved) {
      _pulse.forward(from: 0);
      _solveTimer?.cancel();
      _solveTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          widget.session.host.solve(optimalMoves: _puzzle.optimalMoves);
        }
      });
    }
  }

  bool get _solved => _puzzle.isSolved;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = widget.session.game.accent;
    final lightsLeft = _puzzle.lights.fold<int>(
      0,
      (sum, row) => sum + row.where((light) => light).length,
    );
    final nudgeCell = widget.session.firstMoveNudgeCell;
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
            ),
          LayoutBuilder(
            builder: (context, constraints) {
          final side = constraints.maxWidth
              .clamp(0.0, constraints.maxHeight)
              .toDouble();
          return SizedBox(
            width: side,
            height: side,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final celebrateTint = _celebrating
                    ? Color.lerp(
                        colors.surfaceAlt,
                        GameAccents.tint(context, accent, alpha: 0.25),
                        Curves.easeOut.transform(_pulse.value),
                      )!
                    : colors.surfaceAlt;
                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _puzzle.size,
                    mainAxisSpacing: AppDimens.space2,
                    crossAxisSpacing: AppDimens.space2,
                  ),
                  itemCount: _puzzle.size * _puzzle.size,
                  itemBuilder: (context, index) {
                    final r = index ~/ _puzzle.size;
                    final c = index % _puzzle.size;
                    final isHint = _hintCell == (r: r, c: c) ||
                        (nudgeCell != null && index == nudgeCell);
                    return LightTile(
                      lit: _puzzle.lights[r][c],
                      isHint: isHint,
                      accent: accent,
                      celebrateTint: celebrateTint,
                      onTap: () => _press((r: r, c: c)),
                    );
                  },
                );
              },
            ),
          );
        },
          ),
          if (!_celebrating)
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.space3),
              child: Text(
                lightsLeft == 0
                    ? 'All clear!'
                    : lightsLeft == 1
                        ? '1 light left'
                        : '$lightsLeft lights left',
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
