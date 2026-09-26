import 'package:flutter/material.dart';

import 'puzzle_session.dart';

/// The contract every game must fulfil.
///
/// The registry, home screen, level selection, gameplay shell, hint flow and
/// progress system all work against this interface only — adding a new game
/// never requires touching navigation or shared UI.
abstract class GameDefinition {
  /// Stable identifier, used for persistence keys.
  String get id;

  String get name;

  /// One short sentence shown on cards and headers.
  String get tagline;

  /// How to play — surfaced on first play and from the gameplay menu.
  String get instructions;

  IconData get icon;

  /// Accent color. Must stay inside the shared saturation family.
  Color get accent;

  int get totalLevels;

  /// Whether this game offers a local 2-player mode on one device.
  bool get supportsTwoPlayer => false;

  /// Whether the game is playable. Unavailable games render as quiet
  /// "coming soon" entries and never appear in Daily.
  bool get isAvailable => true;

  /// Deterministic seed so every player gets identical, reproducible levels.
  int seedForLevel(int level) => Object.hash(id, level * 31 + 7, 0x5EED);

  /// Deterministic seed for the daily challenge of a given day.
  int seedForDaily(DateTime day) =>
      Object.hash(id, day.year * 372 + day.month * 31 + day.day, 0xDA11);

  /// Chapters group levels into difficulty arcs (default: blocks of 10).
  int chapterOf(int level) => (level - 1) ~/ 10;

  int get chapterCount => (totalLevels / 10).ceil();

  String chapterName(int chapterIndex) {
    const names = [
      'Foundations',
      'New Constraints',
      'Combinations',
      'Planning',
      'Mastery',
      'Deep Reasoning',
    ];
    return names[chapterIndex.clamp(0, names.length - 1)];
  }

  String chapterDescription(int chapterIndex) {
    const descriptions = [
      'Learn the core mechanic',
      'One new idea enters the mix',
      'Everything you know, combined',
      'Start thinking ahead',
      'The hard part begins',
      'Nothing held back',
    ];
    return descriptions[chapterIndex.clamp(0, descriptions.length - 1)];
  }

  /// Creates the playable board for the given session.
  /// Only called when [isAvailable] is true.
  PuzzleGameWidget createBoard(PuzzleSession session);

  /// The quiet status line the shell shows when a session starts, before
  /// the board has any say.
  ///
  /// Boards must never emit to `session.note` during their own
  /// `initState()` — that runs while the shell is building. They announce
  /// their starting note through this hook instead and emit only later,
  /// from timers or user-interaction callbacks.
  String? initialNoteFor(PuzzleSession session) => null;

  /// First-time introduction, section "How it works" — shown once when the
  /// player first opens this game, and from the gameplay "How to play"
  /// menu item. Empty list = the game has no introduction yet.
  List<String> get howItWorks => const [];

  /// First-time introduction, section "How to play".
  List<String> get howToPlay => const [];

  /// A single friendly first-move suggestion for brand-new players, shown
  /// once (globally, not per game) on level 1 until the first level is
  /// ever completed. Null = this game has no nudge (e.g. random deals).
  ///
  /// The string interpolates the cell the player should tap. Boards call
  /// `NudgeBridge` through the shell; the shell owns persistence.
  String? firstMoveNudge(PuzzleSession session) => null;

  /// Index of the cell to pulse for [firstMoveNudge], in board order
  /// (row-major from 0). Return null when the board is already past the
  /// opening position (e.g. a resumed level).
  int? nudgeCellIndex(PuzzleSession session) => null;
}
