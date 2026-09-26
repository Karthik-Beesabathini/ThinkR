/// SwitchYard Escape — pure-Dart railway escape engine.
///
/// Design rules baked into this file:
///  • Rails decide the route. A train's path is fully determined by the
///    track topology from its head and the current switch states — the
///    player only chooses WHICH train to move, and WHEN.
///  • A train moves as one rigid body: the head leads along the route and
///    every wagon follows in the head's tracks.
///  • Blocked, never unfair: another train directly in front (adjacent
///    cell) means the train simply does not move.
///  • A crash happens only when the player dispatches a train onto a
///    track occupied further ahead — the driver had room to start but
///    could not stop in time. The occupying train is always visible on
///    the board, so every crash is the player's own call.
///
/// No Flutter imports: the engine is headless-testable.
library;

// ---------------------------------------------------------------------------
// models
// ---------------------------------------------------------------------------

/// Movement direction on the grid.
enum Dir { up, right, down, left }

extension DirStep on Dir {
  int get dx => switch (this) {
        Dir.up => -1,
        Dir.down => 1,
        Dir.left => 0,
        Dir.right => 0,
      };
  int get dy => switch (this) {
        Dir.up => 0,
        Dir.down => 0,
        Dir.left => -1,
        Dir.right => 1,
      };

  Dir get opposite => switch (this) {
        Dir.up => Dir.down,
        Dir.down => Dir.up,
        Dir.left => Dir.right,
        Dir.right => Dir.left,
      };
}

/// One designed switch: entering while moving [from] exits either
/// [straight] (state A) or [branch] (state B). The active branch is
/// painted solid; the idle branch paints dashed.
class SwitchDef {
  const SwitchDef({
    required this.row,
    required this.col,
    required this.from,
    required this.straight,
    required this.branch,
  });

  final int row;
  final int col;

  /// Movement direction a train has when it enters this cell.
  final Dir from;

  /// Exit movement direction in state A (the resting route).
  final Dir straight;

  /// Exit movement direction in state B (the diverged route).
  final Dir branch;
}

typedef Cell = ({int r, int c});

/// One train spec from the level data.
class TrainSpec {
  const TrainSpec({
    required this.r,
    required this.c,
    required this.facing,
    required this.length,
    required this.tone,
  });

  /// Head cell.
  final int r;
  final int c;

  /// Movement direction the train will take when first dispatched.
  final Dir facing;

  /// Number of segments (engine + wagons).
  final int length;

  /// Palette index for the painter.
  final int tone;
}

/// Data-only level: the single source of truth the engine loads.
class LevelData {
  const LevelData({
    required this.id,
    required this.rows,
    required this.cols,
    required this.tracks,
    required this.trains,
    required this.exits,
    this.switches = const [],
    required this.difficulty,
    required this.idea,
    this.solution = const [],
  });

  final int id;
  final int rows;
  final int cols;

  /// Row-major grid: the dirs each track cell connects, or null for
  /// empty cells. Switch cells carry their connectivity too (the engine
  /// unions entry + both branches).
  final List<List<Set<Dir>?>> tracks;

  final List<TrainSpec> trains;

  /// An exit is the move that leaves the board: from cell (r, c) moving
  /// [out]. Must target an off-board cell.
  final List<({int r, int c, Dir out})> exits;

  final List<SwitchDef> switches;
  final int difficulty;

  /// The one-line puzzle concept. Dev documentation only.
  final String idea;

  /// Verified action sequence ("T0" dispatch train 0, "S0" toggle switch
  /// 0). Stored for development/testing — never shown to players. May be
  /// empty; the solver test is the authoritative verification.
  final List<String> solution;
}

/// Mutable train state. Segments are head-first; segment 0 is the engine.
class Train {
  Train({
    required this.id,
    required this.tone,
    required this.length,
    required List<Cell> segments,
    required this.facing,
  }) : _segments = List<Cell>.of(segments);

  final int id;
  final int tone;
  final int length;
  List<Cell> _segments;
  Dir facing;

  Cell get head => _segments.first;
  Cell get tail => _segments.last;
  bool get escaped => _segments.isEmpty;
  List<Cell> get segments => List.unmodifiable(_segments);

  void setSegments(List<Cell> next, Dir facingDir) {
    _segments = next;
    facing = facingDir;
  }

  Train deepCopy() => Train(
        id: id,
        tone: tone,
        length: length,
        segments: _segments,
        facing: facing,
      );
}

/// Result of tapping a train.
enum DispatchOutcome { moved, exited, blocked, crash }

class DispatchResult {
  const DispatchResult(
    this.outcome, {
    this.blockedBy,
    this.crashCell,
    this.path = const [],
  });

  final DispatchOutcome outcome;

  /// For [DispatchOutcome.blocked]: the id of the train in the way.
  final int? blockedBy;

  /// For [DispatchOutcome.crash]: where the impact happens.
  final Cell? crashCell;

  /// Cells the head will traverse (animation + solver pathing).
  final List<Cell> path;
}

/// The route a dispatched train would take: the cells its head enters in
/// order, and whether the route ends by leaving the board through an exit.
typedef RouteInfo = ({List<Cell> cells, bool exits});

// ---------------------------------------------------------------------------
// engine
// ---------------------------------------------------------------------------

class SwitchYardEngine {
  SwitchYardEngine(this.level)
      : rows = level.rows,
        cols = level.cols {
    _trains = [
      for (var i = 0; i < level.trains.length; i++)
        Train(
          id: i,
          tone: level.trains[i].tone,
          length: level.trains[i].length,
          facing: level.trains[i].facing,
          segments: _initialSegments(level.trains[i]),
        ),
    ];
    _switchStates = {
      for (var i = 0; i < level.switches.length; i++) i: false,
    };
  }

  final LevelData level;
  final int rows;
  final int cols;

  late final List<Train> _trains;
  late final Map<int, bool> _switchStates;
  final List<Map<String, dynamic>> _history = [];

  List<Train> get trains => _trains;
  int get switchCount => level.switches.length;
  bool get isSwitchPresent => level.switches.isNotEmpty;

  /// True when every train has left the board.
  bool get solved => _trains.every((t) => t.escaped);

  bool get canUndo => _history.isNotEmpty;

  Set<Dir>? trackAt(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return null;
    return level.tracks[r][c];
  }

  /// Index of the switch at a cell, or null.
  int? switchIndexAt(int r, int c) {
    for (var i = 0; i < level.switches.length; i++) {
      final s = level.switches[i];
      if (s.row == r && s.col == c) return i;
    }
    return null;
  }

  bool switchStateB(int index) => _switchStates[index] ?? false;

  /// Toggle a switch. Returns true when the state changed.
  bool toggleSwitch(int index) {
    final before = _switchStates[index]!;
    _switchStates[index] = !before;
    _history.add({'type': 'sw', 'index': index, 'before': before});
    return before != _switchStates[index];
  }

  List<Cell> _initialSegments(TrainSpec spec) {
    final back = spec.facing.opposite;
    return [
      for (var i = 0; i < spec.length; i++)
        (r: spec.r + back.dx * i, c: spec.c + back.dy * i),
    ];
  }

  /// Connectivity of a cell honoring switch overrides.
  Set<Dir>? connectivity(int r, int c) {
    final sw = switchIndexAt(r, c);
    if (sw != null) {
      final s = level.switches[sw];
      return {s.from.opposite, s.straight, s.branch};
    }
    return trackAt(r, c);
  }

  /// The movement direction a train takes when leaving cell (r,c) having
  /// entered it moving [m]. Returns null when the cell cannot route it.
  Dir? routeOut(int r, int c, Dir m) {
    final sw = switchIndexAt(r, c);
    if (sw != null) {
      final s = level.switches[sw];
      if (s.from == m) {
        return switchStateB(sw) ? s.branch : s.straight;
      }
      // Entered from a side the switch does not steer: go straight when
      // the connectivity allows it, else fall through to plain rules.
    }
    final conn = connectivity(r, c);
    if (conn == null) return null;
    if (conn.length == 2) {
      // Straight or curve: leave through the side other than the entry.
      final entry = m.opposite;
      for (final d in conn) {
        if (d != entry) return d;
      }
      return null;
    }
    // Crossing (4-way): straight through.
    if (conn.contains(m)) return m;
    return null;
  }

  /// The route a dispatched train would take. The head's cells in order,
  /// ending at an exit move, a dead end, or a revisit (loop guard).
  ///
  /// [exits] is true only when the last cell leaves the board through a
  /// declared exit.
  RouteInfo routeInfo(Train train) {
    if (train.escaped) return (cells: const [], exits: false);
    final route = <Cell>[];
    final seen = <int>{train.head.r * cols + train.head.c};
    var cur = train.head;
    var m = train.facing;

    for (var step = 0; step < rows * cols; step++) {
      final out = routeOut(cur.r, cur.c, m);
      if (out == null) break;
      final next = (r: cur.r + out.dx, c: cur.c + out.dy);

      // A declared exit always wins: it leaves the board from here.
      final isExit = level.exits
          .any((e) => e.r == cur.r && e.c == cur.c && e.out == out);
      if (isExit) return (cells: route, exits: true);

      final offBoard =
          next.r < 0 || next.r >= rows || next.c < 0 || next.c >= cols;
      if (offBoard) return (cells: const [], exits: false);
      // The destination must connect back: a route may never continue
      // onto empty ground or into a tile that does not accept this entry.
      final nextConn = connectivity(next.r, next.c);
      if (nextConn == null || !nextConn.contains(out.opposite)) break;
      if (!seen.add(next.r * cols + next.c)) break;
      route.add(next);
      cur = next;
      m = out;
    }
    return (cells: route, exits: false);
  }

  /// Convenience: the head's cells for [train] (empty when it cannot move).
  List<Cell> routeFor(Train train) => routeInfo(train).cells;

  /// Attempt to dispatch [trainId]. The engine is mutated only on
  /// moved/exited. Blocked and crash leave the board untouched.
  DispatchResult dispatch(int trainId) {
    final train = _trains.firstWhere((t) => t.id == trainId);
    if (train.escaped) {
      return const DispatchResult(DispatchOutcome.blocked);
    }
    final info = routeInfo(train);
    final route = info.cells;
    if (route.isEmpty) {
      // No safe route exists (the rails end without an exit).
      return const DispatchResult(DispatchOutcome.blocked);
    }

    // Occupancy by other trains.
    final occupied = <int, int>{};
    for (final other in _trains) {
      if (other.id == trainId) continue;
      for (final s in other.segments) {
        occupied[s.r * cols + s.c] = other.id;
      }
    }

    // First occupied cell along the route decides the outcome:
    //  adjacent (distance 1) → blocked, the train does not start;
    //  further ahead (distance ≥ 2) → crash, it could not stop in time.
    for (var i = 0; i < route.length; i++) {
      final cell = route[i];
      final blocker = occupied[cell.r * cols + cell.c];
      if (blocker != null) {
        if (i == 0) {
          return DispatchResult(
            DispatchOutcome.blocked,
            blockedBy: blocker,
            path: route,
          );
        }
        return DispatchResult(
          DispatchOutcome.crash,
          crashCell: cell,
          path: route,
        );
      }
    }

    // Clear route: apply the move as one rigid body. Every segment keeps
    // the head's track: segment i lands on the path cell it has reached,
    // and any wagon still behind the path start simply stays put.
    final previous = [for (final s in train.segments) s];
    final previousFacing = train.facing;
    final path = [train.head, ...route];
    final travel = route.length;
    final List<Cell> nextSegments = info.exits
        ? const []
        : [
            for (var i = 0; i < train.length; i++)
              i <= travel ? path[travel - i] : previous[i],
          ];
    final nextFacing = travel >= 1
        ? _stepDir(path[travel - 1], path[travel])
        : previousFacing;

    _history.add({
      'type': 'mv',
      'id': trainId,
      'segments': previous,
      'facing': previousFacing,
    });
    train.setSegments(nextSegments, nextFacing);
    return DispatchResult(
      info.exits ? DispatchOutcome.exited : DispatchOutcome.moved,
      path: route,
    );
  }

  /// Direction of a single grid step.
  Dir _stepDir(Cell from, Cell to) {
    if (to.r > from.r) return Dir.down;
    if (to.r < from.r) return Dir.up;
    if (to.c > from.c) return Dir.right;
    return Dir.left;
  }

  /// Undo the last action (dispatch or switch toggle). Returns true when
  /// something was undone.
  bool undo() {
    if (_history.isEmpty) return false;
    final entry = _history.removeLast();
    if (entry['type'] == 'mv') {
      final train = _trains.firstWhere((t) => t.id == entry['id'] as int);
      train.setSegments(
        [for (final s in entry['segments'] as List<Cell>) s],
        entry['facing'] as Dir,
      );
    } else {
      _switchStates[entry['index'] as int] = entry['before'] as bool;
    }
    return true;
  }

  // --- state copy (solver + save/resume) -------------------------------------

  SwitchYardEngine clone() {
    final copy = SwitchYardEngine(level);
    for (var i = 0; i < _trains.length; i++) {
      final t = _trains[i];
      copy._trains[i].setSegments([for (final s in t.segments) s], t.facing);
    }
    for (final entry in _switchStates.entries) {
      copy._switchStates[entry.key] = entry.value;
    }
    return copy;
  }

  /// Stable state hash for the solver's visited set.
  String stateKey() {
    final b = StringBuffer();
    for (final t in _trains) {
      b.write(t.id);
      b.write(':');
      for (final s in t.segments) {
        b.write(s.r);
        b.write(',');
        b.write(s.c);
        b.write(';');
      }
      b.write('|');
    }
    final switches = [
      for (final e in _switchStates.entries) '${e.key}:${e.value ? 1 : 0}',
    ].join(',');
    b.write('#');
    b.write(switches);
    return b.toString();
  }

  // --- save / resume -----------------------------------------------------------

  Map<String, dynamic> serialize() => {
        'trains': [
          for (final t in _trains)
            {
              'id': t.id,
              'facing': t.facing.index,
              'segments': [
                for (final s in t.segments) [s.r, s.c],
              ],
            },
        ],
        'switches': [
          for (final e in _switchStates.entries)
            {'index': e.key, 'b': e.value},
        ],
      };

  /// Restores serialized state onto this engine. Corrupt payloads are
  /// ignored (the level then simply starts fresh).
  void restore(Map<String, dynamic> json) {
    try {
      final trains = json['trains'] as List?;
      if (trains != null) {
        for (final raw in trains) {
          final map = raw as Map;
          final id = (map['id'] as num).toInt();
          final train = _trains.firstWhere((t) => t.id == id);
          final segments = [
            for (final pair in (map['segments'] as List))
              (
                r: ((pair as List)[0] as num).toInt(),
                c: (pair[1] as num).toInt(),
              ),
          ];
          train.setSegments(
            segments,
            Dir.values[(map['facing'] as num).toInt()],
          );
        }
      }
      final switches = json['switches'] as List?;
      if (switches != null) {
        for (final raw in switches) {
          final map = raw as Map;
          _switchStates[(map['index'] as num).toInt()] = map['b'] == true;
        }
      }
    } catch (_) {
      // Corrupt save: keep the fresh deal.
    }
  }
}
