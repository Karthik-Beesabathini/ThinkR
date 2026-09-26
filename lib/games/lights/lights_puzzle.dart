import 'dart:math';

/// A single board cell.
typedef LightCell = ({int r, int c});

/// Pure Lights (Lights Out) puzzle logic — no Flutter, fully testable.
///
/// Levels are generated deterministically from a seed: start with all
/// lights off, then apply N random "cross presses". This guarantees
/// solvability and gives every player the same levels.
///
/// Because the board state is linear over GF(2), the solution is tracked
/// as the parity of generating presses XOR player presses. When the board
/// is solved, the parity set is empty — so hints are always exact.
class LightsPuzzle {
  LightsPuzzle({required int level, required int seed}) {
    size = _sizeForLevel(level);
    final pressCount = (2 + level ~/ 5).clamp(2, size * size - 2);
    final rng = Random(seed);

    final allCells = <LightCell>[
      for (var r = 0; r < size; r++)
        for (var c = 0; c < size; c++) (r: r, c: c),
    ]..shuffle(rng);

    generatingPresses = allCells.take(pressCount).toSet();
    solutionParity = {...generatingPresses};

    lights = List.generate(size, (_) => List.filled(size, false));
    for (final cell in generatingPresses) {
      _toggleCross(cell);
    }
  }

  late final int size;

  /// Board state: true = lit.
  late final List<List<bool>> lights;

  /// Presses used to generate the level (defines "perfect").
  late final Set<LightCell> generatingPresses;

  /// Parity of (generating presses) XOR (player presses). Empty ⟺ solved.
  late final Set<LightCell> solutionParity;

  int get optimalMoves => generatingPresses.length;

  bool get isSolved => lights.every((row) => row.every((light) => !light));

  bool get hasHint => solutionParity.isNotEmpty;

  LightCell hintCell() => solutionParity.first;

  /// Presses a cell and toggles it plus its orthogonal neighbors.
  void press(LightCell cell) {
    _toggleCross(cell);
    if (solutionParity.contains(cell)) {
      solutionParity.remove(cell);
    } else {
      solutionParity.add(cell);
    }
  }

  void _toggleCross(LightCell cell) {
    void toggle(int r, int c) {
      if (r >= 0 && r < size && c >= 0 && c < size) {
        lights[r][c] = !lights[r][c];
      }
    }

    toggle(cell.r, cell.c);
    toggle(cell.r - 1, cell.c);
    toggle(cell.r + 1, cell.c);
    toggle(cell.r, cell.c - 1);
    toggle(cell.r, cell.c + 1);
  }

  static int _sizeForLevel(int level) {
    if (level <= 12) return 3;
    if (level <= 32) return 4;
    return 5;
  }

  /// Restores a previously saved board (save/resume support). Fields are
  /// assigned directly — no reshuffling, the exact board comes back.
  LightsPuzzle.fromState({
    required this.size,
    required this.lights,
    required this.solutionParity,
    required this.generatingPresses,
  });

  /// Serialized in-progress state for the save/resume layer.
  Map<String, dynamic> serialize() => {
        'size': size,
        'lights': [
          for (final row in lights) [for (final light in row) light ? 1 : 0],
        ],
        'parity': [for (final cell in solutionParity) '${cell.r}:${cell.c}'],
        'generated': [
          for (final cell in generatingPresses) '${cell.r}:${cell.c}',
        ],
      };

  /// Rebuilds a board from [serialize] output. Returns null when the
  /// payload is malformed (the level then starts fresh instead).
  static LightsPuzzle? fromSerialized(Map<String, dynamic> json) {
    final size = (json['size'] as num?)?.toInt();
    final rawLights = json['lights'];
    final rawParity = json['parity'];
    final rawGenerated = json['generated'];
    if (size == null ||
        size < 2 ||
        rawLights is! List ||
        rawParity is! List ||
        rawGenerated is! List) {
      return null;
    }
    LightCell parseCell(Object? cell) {
      final parts = (cell as String).split(':');
      return (r: int.parse(parts[0]), c: int.parse(parts[1]));
    }

    final lights = [
      for (final row in rawLights)
        [for (final value in (row as List)) (value as num) != 0],
    ];
    if (lights.length != size ||
        lights.any((row) => row.length != size)) {
      return null;
    }
    return LightsPuzzle.fromState(
      size: size,
      lights: lights,
      solutionParity: rawParity.map(parseCell).toSet(),
      generatingPresses: rawGenerated.map(parseCell).toSet(),
    );
  }
}
