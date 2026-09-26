import 'package:flutter/material.dart';

import '../../app/router.dart';
import '../../core/design_system/design_system.dart';
import '../../core/multiplayer/nearby_host_session.dart';
import '../../core/models/game_definition.dart';
import '../../core/models/puzzle_session.dart';
import '../../core/services/service_scope.dart';

/// Multiplayer — pass-and-play on one device, or a real duel across two
/// nearby phones (Bluetooth/BLE/Wi-Fi via Android Nearby Connections).
///
/// Nothing here invents a separate visual language: same cards, chips and
/// buttons as everywhere else in Thinkr.
class MultiplayerScreen extends StatelessWidget {
  const MultiplayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final registry = ServiceScope.of(context).registry;
    final duelGames = [
      for (final game in registry.available)
        if (game.supportsTwoPlayer) game,
    ];
    final text = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Multiplayer',
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppDimens.space7),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.space5,
              AppDimens.pagePadding,
              0,
            ),
            child: Text(
              'Two players. Take turns, keep score, no setup.',
              style: text.bodyMedium,
            ),
          ),
          SectionHeader(title: 'Duel games'),
          for (final game in duelGames)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.pagePadding,
              ),
              child: _DuelCard(game: game),
            ),
          if (duelGames.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
              child: EmptyState(
                title: 'No duels yet',
                message: 'Pass-and-play games will appear here.',
              ),
            ),
          SectionHeader(title: 'More duels coming'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
            child: _ComingSoonRow(name: 'Lights Duel'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
            child: _ComingSoonRow(name: 'Shift Race'),
          ),
        ],
      ),
    );
  }
}

/// The duel entry: name, promise, and the two ways to play it.
class _DuelCard extends StatelessWidget {
  const _DuelCard({required this.game});

  final GameDefinition game;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.space3),
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
          Row(
            children: [
              AccentMark(accent: game.accent, icon: game.icon),
              const SizedBox(width: AppDimens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name.toUpperCase(),
                      style: text.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      game.tagline,
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.space4),
          FilledButton(
            onPressed: () => AppRouter.pushGameplay(
              context,
              PuzzleSession(
                game: game,
                seed: game.seedForLevel(1),
                mode: PuzzleMode.twoPlayer,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: game.accent,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMedium),
              ),
              textStyle: text.labelLarge,
            ),
            child: const Text('Same phone — pass & play'),
          ),
          const SizedBox(height: AppDimens.space2),
          SecondaryButton(
            label: 'Two phones nearby',
            color: game.accent,
            onPressed: () => _pickNearbyRole(context, game),
          ),
        ],
      ),
    );
  }

  void _pickNearbyRole(BuildContext context, GameDefinition game) {
    final text = Theme.of(context).textTheme;
    showAppSheet(
      context: context,
      builder: (sheetContext) => SheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: AppDimens.space4),
            Text(
              '${game.name.toUpperCase()} · NEARBY',
              style: text.labelSmall!.copyWith(
                letterSpacing: 1.6,
                color: game.accent,
              ),
            ),
            const SizedBox(height: AppDimens.space2),
            Text(
              'Both phones need Thinkr open with Bluetooth and location '
              'permission. One hosts, one joins.',
              style: text.bodySmall,
            ),
            const SizedBox(height: AppDimens.space5),
            PrimaryButton(
              label: 'Host this game',
              color: game.accent,
              onPressed: () {
                Navigator.pop(sheetContext);
                AppRouter.pushNearbyDuel(context, NearbyRole.host);
              },
            ),
            const SizedBox(height: AppDimens.space2),
            SecondaryButton(
              label: 'Join a friend',
              onPressed: () {
                Navigator.pop(sheetContext);
                AppRouter.pushNearbyDuel(context, NearbyRole.guest);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet "soon" row for announced duel modes — same language as home.
class _ComingSoonRow extends StatelessWidget {
  const _ComingSoonRow({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space2),
      child: Row(
        children: [
          Icon(Icons.sports_esports_outlined, size: 18, color: colors.locked),
          const SizedBox(width: AppDimens.space3),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium!
                  .copyWith(color: colors.textSecondary),
            ),
          ),
          QuietChip(label: 'SOON', color: colors.textTertiary),
        ],
      ),
    );
  }
}
