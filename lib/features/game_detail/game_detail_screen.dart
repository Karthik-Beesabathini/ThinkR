import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/models/game_definition.dart';
import '../../core/models/game_progress.dart';
import '../../core/models/puzzle_session.dart';
import '../../core/services/game_state_service.dart';
import '../../core/services/service_scope.dart';
import '../../core/storage/local_storage.dart';
import '../../core/utils/formatters.dart';

/// Game detail: title, promise, Continue, and the level grid grouped into
/// difficulty chapters. States are expressed through fills, borders,
/// symbols and labels — never color alone.
///
/// The first time a game is opened, its two-section rules introduction
/// ("How it works" / "How to play") is shown once, persisted per game.
class GameDetailScreen extends StatefulWidget {
  const GameDetailScreen({super.key, required this.game});

  final GameDefinition game;

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  bool _introHandled = false;

  @override
  void initState() {
    super.initState();
    // The introduction is a modal sheet: it must be shown after the first
    // frame (showing a route during build is illegal), exactly once per
    // game, and never re-triggered by rebuilds — hence the [_introHandled]
    // guard plus the persisted per-game flag.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showIntroOnce());
  }

  void _showIntroOnce() {
    if (_introHandled || !mounted) return;
    final game = widget.game;
    if (!game.isAvailable || game.howItWorks.isEmpty || game.howToPlay.isEmpty) {
      return;
    }
    final services = ServiceScope.of(context);
    final flagKey = '${StorageKeys.seenInstructionsPrefix}${game.id}';
    if (services.storage.getBool(flagKey)) return;

    _introHandled = true;
    // Persist immediately: the introduction is a first-run experience,
    // not a nag — dismissing it must not bring it back.
    services.storage.setBool(flagKey, true);
    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => HowToPlaySheet(
        gameName: game.name,
        howItWorks: game.howItWorks,
        howToPlay: game.howToPlay,
        accent: game.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final services = ServiceScope.of(context);
    final progress = services.progress.progressOf(game);
    final text = Theme.of(context).textTheme;

    // Unfinished in-progress level, if any. The card rebuilds whenever a
    // save appears or disappears (GameStateManager notifies the scope).
    final savedGame = game.isAvailable
        ? services.gameStates.latestSavedGame(game.id)
        : null;
    final resumeGame =
        (savedGame != null &&
                savedGame.level >= 1 &&
                savedGame.level <= game.totalLevels &&
                !progress.isCompleted(savedGame.level))
            ? savedGame
            : null;

    return AppScaffold(
      title: game.name,
      leading: const AppBackButton(),
      actions: [
        if (game.supportsTwoPlayer)
          Padding(
            padding: const EdgeInsets.only(right: AppDimens.space2),
            child: Center(child: QuietChip(label: '2 PLAYER', color: game.accent)),
          ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.space7),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.space4,
              AppDimens.pagePadding,
              0,
            ),
            child: Text(game.tagline, style: text.bodyMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.pagePadding,
              vertical: AppDimens.space5,
            ),
            child: _ContinueButton(
              game: game,
              progress: progress,
              accent: game.accent,
            ),
          ),
          if (resumeGame != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                0,
                AppDimens.pagePadding,
                AppDimens.space2,
              ),
              child: _ResumeCard(game: game, saved: resumeGame),
            ),
          if (game.supportsTwoPlayer)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                0,
                AppDimens.pagePadding,
                AppDimens.space2,
              ),
              child: _TwoPlayerCard(game: game),
            ),
          for (var chapter = 0; chapter < game.chapterCount; chapter++)
            _ChapterSection(
              game: game,
              progress: progress,
              chapter: chapter,
              accent: game.accent,
              onLevelTap: _openLevel,
            ),
        ],
      ),
    );
  }

  /// Opening a level. If an unfinished attempt for *that* level is saved,
  /// the player chooses between continuing it and starting over — tapping a
  /// tile must never silently throw away matched work. Otherwise the level
  /// opens fresh.
  void _openLevel(int level) {
    final game = widget.game;
    final services = ServiceScope.of(context);
    final progress = services.progress.progressOf(game);
    final saved = progress.isCompleted(level)
        ? null
        : services.gameStates.resumeGame(game.id, level);

    if (saved == null || saved.isEmptyAttempt) {
      AppRouter.pushGameplay(context, PuzzleSession.forLevel(game, level));
      return;
    }

    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ResumeGameSheet(
        gameName: game.name,
        level: saved.level,
        moves: saved.moves,
        seconds: saved.seconds,
        accent: game.accent,
        onContinue: () {
          Navigator.pop(sheetContext);
          AppRouter.pushGameplay(
            context,
            PuzzleSession.forLevel(game, level, resume: saved.toResumeState()),
          );
        },
        onRestart: () {
          Navigator.pop(sheetContext);
          unawaited(services.gameStates.clearGameState(game.id, level));
          AppRouter.pushGameplay(context, PuzzleSession.forLevel(game, level));
        },
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.game,
    required this.progress,
    required this.accent,
  });

  final GameDefinition game;
  final GameProgressData progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final level = progress.solvedCount == 0 ? 1 : progress.currentLevel;
    final isComplete = progress.solvedCount >= game.totalLevels;
    final label = isComplete
        ? 'All ${game.totalLevels} levels solved — replay any'
        : 'Continue — Level $level';

    return FilledButton.icon(
      onPressed: isComplete
          ? null
          : () => AppRouter.pushGameplay(
                context,
                PuzzleSession.forLevel(game, level),
              ),
      icon: Icon(
        isComplete ? Icons.check_rounded : Icons.play_arrow_rounded,
        size: 20,
      ),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: accent.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
        ),
        textStyle: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.game, required this.saved});

  final GameDefinition game;
  final SavedGameState saved;

  @override
  Widget build(BuildContext context) {
    final services = ServiceScope.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppDimens.space4),
      decoration: BoxDecoration(
        color: GameAccents.tint(context, game.accent, alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(
          color: game.accent.withValues(alpha: 0.30),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'CONTINUE YOUR GAME?',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
              color: game.accent,
            ),
          ),
          const SizedBox(height: AppDimens.space1),
          Text('Level ${saved.level}', style: text.titleMedium),
          const SizedBox(height: 2),
          Text(
            '${saved.moves} moves · ${formatPlayTime(saved.seconds)}',
            style: text.bodySmall,
          ),
          const SizedBox(height: AppDimens.space3),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => AppRouter.pushGameplay(
                    context,
                    PuzzleSession.forLevel(
                      game,
                      saved.level,
                      resume: saved.toResumeState(),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: game.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                    ),
                    textStyle: text.labelLarge,
                  ),
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(width: AppDimens.space2),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    unawaited(
                      services.gameStates
                          .clearGameState(game.id, saved.level),
                    );
                    AppRouter.pushGameplay(
                      context,
                      PuzzleSession(
                        game: game,
                        level: saved.level,
                        seed: game.seedForLevel(saved.level),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.border),
                    backgroundColor: colors.surface,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
                    ),
                    textStyle: text.labelLarge,
                  ),
                  child: const Text('Restart'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TwoPlayerCard extends StatelessWidget {
  const _TwoPlayerCard({required this.game});

  final GameDefinition game;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppDimens.space4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        border: Border.all(color: colors.border, width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TWO PLAYER',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppDimens.space1),
                Text('Play together on one device', style: text.titleMedium),
              ],
            ),
          ),
          const SizedBox(width: AppDimens.space3),
          SecondaryButton(
            label: 'Start',
            expanded: false,
            color: game.accent,
            onPressed: () => AppRouter.pushGameplay(
              context,
              PuzzleSession(
                game: game,
                seed: game.seedForLevel(1),
                mode: PuzzleMode.twoPlayer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterSection extends StatelessWidget {
  const _ChapterSection({
    required this.game,
    required this.progress,
    required this.chapter,
    required this.accent,
    required this.onLevelTap,
  });

  final GameDefinition game;
  final GameProgressData progress;
  final int chapter;
  final Color accent;
  final ValueChanged<int> onLevelTap;

  LevelTileStatus _statusFor(int level) {
    if (progress.isCompleted(level)) {
      return progress.completed[level]!.perfect
          ? LevelTileStatus.completedPerfect
          : LevelTileStatus.completed;
    }
    if (progress.currentLevel == level) return LevelTileStatus.current;
    if (progress.isUnlocked(level)) return LevelTileStatus.available;
    return LevelTileStatus.locked;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final startLevel = chapter * 10 + 1;
    final endLevel = (startLevel + 9).clamp(1, game.totalLevels);
    final isChapterReached = progress.currentLevel >= startLevel;
    final solvedInChapter = [
      for (var level = startLevel; level <= endLevel; level++)
        if (progress.isCompleted(level)) level,
    ].length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.pagePadding,
            AppDimens.space5,
            AppDimens.pagePadding,
            AppDimens.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${game.chapterName(chapter).toUpperCase()} · '
                    'LEVELS $startLevel–$endLevel',
                    style: text.labelSmall!.copyWith(
                      color: isChapterReached ? colors.textTertiary : colors.locked,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$solvedInChapter/${endLevel - startLevel + 1}',
                    style: text.labelSmall!.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                game.chapterDescription(chapter),
                style: text.bodySmall!.copyWith(
                  color: isChapterReached
                      ? colors.textSecondary
                      : colors.locked,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
          child: LevelChapterGrid(
            startLevel: startLevel,
            endLevel: endLevel,
            statusFor: _statusFor,
            accent: accent,
            onLevelTap: onLevelTap,
          ),
        ),
      ],
    );
  }
}
