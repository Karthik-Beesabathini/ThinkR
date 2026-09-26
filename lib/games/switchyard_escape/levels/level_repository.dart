import '../engine/switchyard_engine.dart';

/// Compact authoring helpers for railway levels.
///
/// Track glyphs (which sides a cell connects):
///   ═  left+right      ║  up+down
///   └  up+right        ┘  up+left
///   ┌  down+right      ┐  down+left
///   ┼  all four sides (crossing)
///   ·  (or space) empty — no track
class LevelBuilder {
  LevelBuilder({
    required this.id,
    required this.rows,
    required this.cols,
    required this.idea,
    this.difficulty = 1,
  });

  final int id;
  final int rows;
  final int cols;
  final String idea;
  int difficulty;

  final List<TrainSpec> _trains = [];
  final List<SwitchDef> _switches = [];
  final List<({int r, int c, Dir out})> _exits = [];
  int _nextRow = 0;

  late final List<List<Set<Dir>?>> _tracks = [
    for (var r = 0; r < rows; r++) [for (var c = 0; c < cols; c++) null],
  ];

  /// Parses one row of track glyphs, top to bottom in call order.
  void row(String glyphs) {
    assert(glyphs.length == cols, 'row length != cols');
    final r = _nextRow++;
    for (var c = 0; c < cols; c++) {
      _tracks[r][c] = parseTrack(glyphs[c]);
    }
  }

  void train({
    required int r,
    required int c,
    required Dir facing,
    int length = 2,
    int tone = 0,
  }) {
    _trains.add(TrainSpec(
      r: r,
      c: c,
      facing: facing,
      length: length,
      tone: tone,
    ));
  }

  void switchTrack({
    required int r,
    required int c,
    required Dir from,
    required Dir straight,
    required Dir branch,
  }) {
    _switches.add(SwitchDef(
      row: r,
      col: c,
      from: from,
      straight: straight,
      branch: branch,
    ));
  }

  void exit(int r, int c, Dir out) => _exits.add((r: r, c: c, out: out));

  LevelData build() => LevelData(
        id: id,
        rows: rows,
        cols: cols,
        tracks: _tracks,
        trains: _trains,
        exits: List.unmodifiable(_exits),
        switches: List.unmodifiable(_switches),
        difficulty: difficulty,
        idea: idea,
      );
}

/// Parses a single track glyph. Empty cells return null; an unknown glyph
/// is an authoring error and throws so it fails tests instead of silently
/// becoming phantom track.
Set<Dir>? parseTrack(String char) => switch (char) {
      '═' => {Dir.left, Dir.right},
      '║' => {Dir.up, Dir.down},
      '└' => {Dir.up, Dir.right},
      '┘' => {Dir.up, Dir.left},
      '┌' => {Dir.down, Dir.right},
      '┐' => {Dir.down, Dir.left},
      '┼' => {Dir.up, Dir.down, Dir.left, Dir.right},
      '·' || ' ' => null,
      _ => throw FormatException('Unknown track glyph "$char"'),
    };

/// The designed levels, stage by stage: rails first, then order, then
/// switches, then long trains and combinations. Grows as stages ship.
List<LevelData> buildSwitchYardLevels() {
  final levels = <LevelData>[];

  LevelData lv({
    required int id,
    required int rows,
    required int cols,
    required String idea,
    required int difficulty,
    required List<String> rowsGlyphs,
    required List<TrainSpec> trains,
    List<({int r, int c, Dir out})> exits = const [],
    List<SwitchDef> switches = const [],
  }) {
    return LevelData(
      id: id,
      rows: rows,
      cols: cols,
      tracks: [
        for (final g in rowsGlyphs)
          [for (final ch in g.split('')) parseTrack(ch)],
      ],
      trains: trains,
      exits: exits,
      switches: switches,
      difficulty: difficulty,
      idea: idea,
    );
  }

  TrainSpec t({
    required int r,
    required int c,
    required Dir facing,
    int length = 2,
    int tone = 0,
  }) =>
      TrainSpec(r: r, c: c, facing: facing, length: length, tone: tone);

  // ---------------- stage 1 · learn (1–10) ----------------

  // 1 — one train, one straight: tap and it leaves.
  levels.add(lv(
    id: 1,
    rows: 3,
    cols: 5,
    idea: 'Tap the train — it follows the track out.',
    difficulty: 1,
    rowsGlyphs: ['·····', '═════', '·····'],
    trains: [t(r: 1, c: 1, facing: Dir.right)],
    exits: [(r: 1, c: 4, out: Dir.right)],
  ));

  // 2 — one train, one curve: the rails decide the route.
  levels.add(lv(
    id: 2,
    rows: 4,
    cols: 4,
    idea: 'A single curve — the track steers the train.',
    difficulty: 1,
    rowsGlyphs: ['·║··', '·║··', '·└══', '····'],
    trains: [t(r: 1, c: 1, facing: Dir.down)],
    exits: [(r: 2, c: 3, out: Dir.right)],
  ));

  // 3 — two trains on one line: move the right one first.
  levels.add(lv(
    id: 3,
    rows: 3,
    cols: 6,
    idea: 'Two trains share a line — order decides whether it works.',
    difficulty: 1,
    rowsGlyphs: ['······', '══════', '······'],
    trains: [
      t(r: 1, c: 1, facing: Dir.right, tone: 0),
      t(r: 1, c: 3, facing: Dir.right, tone: 1),
    ],
    exits: [(r: 1, c: 5, out: Dir.right)],
  ));

  return levels;
}
