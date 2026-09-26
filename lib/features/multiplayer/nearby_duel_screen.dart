import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';
import '../../core/multiplayer/nearby_connections_service.dart';
import '../../core/multiplayer/nearby_host_session.dart';
import '../../core/services/service_scope.dart';
import '../../games/memory/memory_game.dart';

/// Screen: Memory duel across two devices (Nearby Connections).
///
/// The board state lives in [NearbyHostSession] (host-authoritative); this
/// widget only renders snapshots and forwards taps. The shared gameplay
/// shell is bypassed deliberately: remote play has its own lobby, exit and
/// disconnect flows, and remote duels never touch level progress.
class NearbyDuelScreen extends StatefulWidget {
  const NearbyDuelScreen({super.key, required this.role});

  final NearbyRole role;

  @override
  State<NearbyDuelScreen> createState() => _NearbyDuelScreenState();
}

class _NearbyDuelScreenState extends State<NearbyDuelScreen> {
  NearbyHostSession? _session;
  NearbySessionState _state = const NearbySessionState(
    status: NearbyStatus.idle,
  );
  bool _permissionsAsked = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final services = ServiceScope.of(context);
    final session = NearbyHostSession(
      service: services.nearby,
      role: widget.role,
      localName: 'Thinkr player',
    );
    session.addListener(_onState);
    _session = session;
    _state = session.state;

    if (!_permissionsAsked) {
      _permissionsAsked = true;
      final granted = await services.nearby.requestPermissions();
      if (!granted) {
        if (!mounted) return;
        setState(() {});
        return;
      }
    }
    if (!mounted) return;
    await session.openLobby();
  }

  void _onState(NearbySessionState s) {
    if (!mounted) return;
    setState(() => _state = s);
  }

  Future<void> _exit() async {
    await _session?.close();
    _session?.dispose();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void dispose() {
    _session?.removeListener(_onState);
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final game = ServiceScope.of(context).registry.byId('memory');
    final accent = game?.accent ?? colors.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exit();
      },
      child: AppScaffold(
        title: widget.role == NearbyRole.host ? 'Host game' : 'Nearby play',
        leading: AppBackButton(onPressed: _exit),
        body: switch (_state.status) {
          NearbyStatus.failed => _FailedView(
              state: _state,
              accent: accent,
              onExit: _exit,
            ),
          _ => _state.setup == null
              ? _LobbyView(
                  state: _state,
                  accent: accent,
                  role: widget.role,
                  onConnect: (peer) => _session?.connectTo(peer),
                  onAccept: (id) => _session?.accept(id),
                  onRetry: _start,
                )
              : _DuelView(
                  session: _session!,
                  state: _state,
                  accent: accent,
                  boardSize: _state.setup!.boardSize,
                ),
        },
      ),
    );
  }
}

// --- lobby ------------------------------------------------------------------

class _LobbyView extends StatelessWidget {
  const _LobbyView({
    required this.state,
    required this.accent,
    required this.role,
    required this.onConnect,
    required this.onAccept,
    required this.onRetry,
  });

  final NearbySessionState state;
  final Color accent;
  final NearbyRole role;
  final ValueChanged<NearbyPeer> onConnect;
  final ValueChanged<String> onAccept;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return ListView(
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
            role == NearbyRole.host
                ? 'Keep this screen open. Your opponent will find you.'
                : 'Both phones: open Thinkr → Duel → Nearby play. '
                    'Then pick the host below.',
            style: text.bodyMedium,
          ),
        ),
        if (state.note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.pagePadding,
              AppDimens.space3,
              AppDimens.pagePadding,
              0,
            ),
            child: InlineBanner(message: state.note!, accent: accent),
          ),
        SectionHeader(title: 'Nearby players'),
        if (role == NearbyRole.guest) ...[
          if (state.peers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.pagePadding,
              ),
              child: Text(
                'Searching… make sure both phones have the app open.',
                style: text.bodySmall!.copyWith(color: colors.textTertiary),
              ),
            )
          else
            for (final peer in state.peers)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.pagePadding,
                ),
                child: _PeerRow(
                  peer: peer,
                  accent: accent,
                  connecting: state.status == NearbyStatus.connecting,
                  onTap: () => onConnect(peer),
                ),
              ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.pagePadding,
            ),
            child: Text(
              'Your game appears on nearby phones automatically.',
              style: text.bodySmall!.copyWith(color: colors.textTertiary),
            ),
          ),
        ],
      ],
    );
  }
}

class _PeerRow extends StatelessWidget {
  const _PeerRow({
    required this.peer,
    required this.accent,
    required this.connecting,
    required this.onTap,
  });

  final NearbyPeer peer;
  final Color accent;
  final bool connecting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.space3),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
        child: InkWell(
          onTap: connecting ? null : onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(AppDimens.space4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimens.radiusLarge),
              border: Border.all(color: colors.border, width: 0.8),
            ),
            child: Row(
              children: [
                Icon(Icons.smartphone_rounded, size: 20, color: accent),
                const SizedBox(width: AppDimens.space3),
                Expanded(
                  child: Text(
                    peer.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  connecting ? 'Connecting…' : 'Tap to join',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: connecting ? colors.textTertiary : accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({
    required this.state,
    required this.accent,
    required this.onExit,
  });

  final NearbySessionState state;
  final Color accent;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.space7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: context.colors.locked),
            const SizedBox(height: AppDimens.space4),
            Text(
              state.note ?? 'Nearby play is unavailable.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimens.space6),
            SecondaryButton(label: 'Close', onPressed: onExit),
          ],
        ),
      ),
    );
  }
}

// --- duel -------------------------------------------------------------------

class _DuelView extends StatelessWidget {
  const _DuelView({
    required this.session,
    required this.state,
    required this.accent,
    required this.boardSize,
  });

  final NearbyHostSession session;
  final NearbySessionState state;
  final Color accent;
  final int boardSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final amHost = session.role == NearbyRole.host;
    final myTurn = amHost
        ? state.currentPlayer == 1
        : state.currentPlayer == 2;
    final myScore = amHost ? state.hostScore : state.guestScore;
    final theirScore = amHost ? state.guestScore : state.hostScore;
    final interactive = state.phase == 'recall' && myTurn && !state.duelOver;

    if (state.duelOver) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Duel over',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppDimens.space2),
              Text(
                state.summary ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppDimens.space6),
              PrimaryButton(
                label: 'Rematch',
                color: accent,
                onPressed: session.requestRematch,
              ),
              const SizedBox(height: AppDimens.space2),
              if (state.rematchRequested)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimens.space2),
                  child: Text(
                    'Waiting for the other player…',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              SecondaryButton(label: 'Leave', onPressed: () => session.close()),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RemoteScoreboard(
            myScore: myScore,
            theirScore: theirScore,
            amHost: amHost,
            peerName: state.peerName,
            accent: accent,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppDimens.space2,
              bottom: AppDimens.space4,
            ),
            child: Text(
              state.note ??
                  switch (state.phase) {
                    'showing' => 'Memorize',
                    'recall' => myTurn ? 'Rebuild it' : 'Their turn…',
                    _ => '',
                  },
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: myTurn ? accent : colors.textTertiary,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final side = math.min(
                constraints.maxWidth,
                constraints.maxHeight,
              ).toDouble();
              return SizedBox(
                width: side,
                height: side,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: boardSize,
                    mainAxisSpacing: AppDimens.space2,
                    crossAxisSpacing: AppDimens.space2,
                  ),
                  itemCount: boardSize * boardSize,
                  itemBuilder: (context, index) {
                    return MemoryCell(
                      key: ValueKey('nearby-memory-cell-$index'),
                      revealed:
                          state.phase == 'showing' && state.shown.contains(index),
                      found: state.found.contains(index),
                      error: state.errorCell == index,
                      errorStamp: state.errorStamp,
                      active: interactive,
                      accent: accent,
                      onTap: () => amHost
                          ? session.hostTap(index)
                          : session.guestTap(index),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RemoteScoreboard extends StatelessWidget {
  const _RemoteScoreboard({
    required this.myScore,
    required this.theirScore,
    required this.amHost,
    required this.peerName,
    required this.accent,
  });

  final int myScore;
  final int theirScore;
  final bool amHost;
  final String? peerName;
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
        side('You', myScore, true),
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
        side(peerName ?? 'Player 2', theirScore, false),
      ],
    );
  }
}
