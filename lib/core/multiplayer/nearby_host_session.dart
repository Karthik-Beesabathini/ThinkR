import 'dart:async';
import 'dart:math';

import 'nearby_connections_service.dart';
import 'nearby_protocol.dart';

/// Role of this device in a nearby duel.
enum NearbyRole { host, guest }

/// Coarse connection state of a nearby session.
enum NearbyStatus {
  idle,
  advertising,
  discovering,
  connecting,
  connected,
  ended,
  failed,
}

/// Setup payload the host deals once both players are connected.
class NearbySetup {
  const NearbySetup({
    required this.seed,
    required this.level,
    required this.rounds,
    required this.boardSize,
  });

  final int seed;
  final int level;
  final int rounds;
  final int boardSize;

  Map<String, dynamic> toMap() => {
        'seed': seed,
        'level': level,
        'rounds': rounds,
        'boardSize': boardSize,
      };

  static NearbySetup fromMap(Map<String, dynamic> map) => NearbySetup(
        seed: (map['seed'] as num?)?.toInt() ?? 1,
        level: (map['level'] as num?)?.toInt() ?? 1,
        rounds: (map['rounds'] as num?)?.toInt() ?? defaultRounds,
        boardSize: (map['boardSize'] as num?)?.toInt() ?? 4,
      );

  static const int defaultRounds = 6;
}

/// One state snapshot of a nearby duel session. The UI rebuilds from this.
class NearbySessionState {
  const NearbySessionState({
    required this.status,
    this.note,
    this.setup,
    this.peerName,
    this.peers = const [],
    this.phase,
    this.shown = const {},
    this.found = const {},
    this.errorCell,
    this.errorStamp = 0,
    this.hostScore = 0,
    this.guestScore = 0,
    this.currentPlayer = 1,
    this.roundNumber = 0,
    this.lastRoundWinner,
    this.duelOver = false,
    this.summary,
    this.rematchRequested = false,
  });

  final NearbyStatus status;
  final String? note;
  final NearbySetup? setup;

  /// Opponent's advertised name (host side) or "Host" (guest side).
  final String? peerName;

  /// Peers discovered while searching (guest side lobby).
  final List<NearbyPeer> peers;

  /// Memory phase: 'showing', 'recall', 'between', 'done'.
  final String? phase;
  final Set<int> shown;
  final Set<int> found;
  final int? errorCell;
  final int errorStamp;

  final int hostScore;
  final int guestScore;

  /// 1 = host, 2 = guest. On the guest device, 2 means "you".
  final int currentPlayer;
  final int roundNumber;

  /// Winner of the most recent round: 1, 2, or null while playing.
  final int? lastRoundWinner;

  final bool duelOver;
  final String? summary;
  final bool rematchRequested;
}

/// Owns the full lifecycle of one nearby duel:
///
/// lobby (advertise/discover/connect) → setup → rounds → result → rematch.
///
/// **Host-authoritative:** the host deals patterns and judges taps; the
/// guest only renders and sends taps. This keeps cheat surface and drift
/// at zero — no board state is ever trusted from the network.
class NearbyHostSession {
  NearbyHostSession({
    required NearbyConnectionsService service,
    required this.role,
    String localName = 'Thinkr player',
  })  : _service = service, // ignore: prefer_initializing_formals
        _localName = localName; // ignore: prefer_initializing_formals

  final NearbyConnectionsService _service;
  final NearbyRole role;
  final String _localName;

  static const int defaultRounds = NearbySetup.defaultRounds;
  static const int duelLevel = 8; // mid difficulty: 4×4 board, 4-cell patterns
  static const int protocolVersion = 1;
  static const Duration revealWindow = Duration(milliseconds: 1900);
  static const Duration missPenalty = Duration(milliseconds: 900);
  static const Duration roundBeat = Duration(milliseconds: 1600);

  NearbySessionState _state = const NearbySessionState(
    status: NearbyStatus.idle,
  );
  NearbySessionState get state => _state;

  final List<void Function(NearbySessionState)> _listeners = [];

  String? _guestEndpoint; // host side: connected guest
  String? _hostEndpoint; // guest side: connected host
  NearbySetup? _setup;
  final List<List<int>> _patterns = [];
  int _currentPattern = 0;
  Set<int> _currentTarget = <int>{};
  Set<int> _hostSelection = <int>{};
  Timer? _revealTimer;
  Timer? _turnTimer;
  bool _disposed = false;
  bool _myRematchVote = false;
  bool _theirRematchVote = false;

  // --- listeners -----------------------------------------------------------

  void addListener(void Function(NearbySessionState) listener) =>
      _listeners.add(listener);

  void removeListener(void Function(NearbySessionState) listener) =>
      _listeners.remove(listener);

  // --- lobby ---------------------------------------------------------------

  /// Starts advertising (host) or discovery (guest).
  Future<void> openLobby() async {
    await _service.start(
      serviceId: NearbyProtocol.serviceId,
      localName: _localName,
      onEvent: _onEvent,
    );
    if (role == NearbyRole.host) {
      // Guard: a fast handshake (or a lobby retry) must never downgrade a
      // session that is already connected.
      if (_state.status == NearbyStatus.idle) {
        _patch(status: NearbyStatus.advertising, note: 'Waiting for a player…');
      }
    } else {
      if (_state.status == NearbyStatus.idle) {
        _patch(
          status: NearbyStatus.discovering,
          peers: const [],
          note: 'Looking for games nearby…',
        );
      }
    }
  }

  /// Guest taps a discovered host to request a connection.
  Future<void> connectTo(NearbyPeer peer) async {
    if (role != NearbyRole.guest) return;
    _patch(
      status: NearbyStatus.connecting,
      note: 'Connecting to ${peer.name}…',
    );
    await _service.requestConnection(peer.id, peer.id);
  }

  /// Host accepts an incoming request from the lobby UI.
  Future<void> accept(String endpointId) async {
    await _service.acceptConnection(endpointId);
  }

  /// Politely ends the session and releases the radios.
  Future<void> close() async {
    final peer = role == NearbyRole.host ? _guestEndpoint : _hostEndpoint;
    if (peer != null) {
      unawaited(_send(peer, {'type': NearbyProtocol.typeLeave}));
    }
    _revealTimer?.cancel();
    _turnTimer?.cancel();
    await _service.stop();
    _patch(status: NearbyStatus.ended);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _revealTimer?.cancel();
    _turnTimer?.cancel();
    _listeners.clear();
  }

  // --- platform events ------------------------------------------------------

  void _onEvent(NearbyEvent event) {
    if (_disposed) return;
    switch (event) {
      case PeerDiscovered():
        if (role == NearbyRole.guest &&
            _state.status != NearbyStatus.connected) {
          final peers = [
            ..._state.peers.where((p) => p.id != event.peer.id),
            event.peer,
          ];
          _patch(peers: peers);
        }
      case PeerLost():
        if (role == NearbyRole.guest) {
          _patch(
            peers: _state.peers.where((p) => p.id != event.peerId).toList(),
          );
        }
      case ConnectionRequested():
        if (role == NearbyRole.host) {
          // One room, one guest: a second request is politely declined.
          if (_guestEndpoint != null) {
            _patch(note: '${event.name} tried to join — room is full.');
            return;
          }
          unawaited(_acceptAsHost(event.peerId, event.name));
        } else {
          // The guest initiated the request, but Nearby fires the
          // handshake on both sides — the guest must accept its end too.
          unawaited(_service.acceptConnection(event.peerId));
        }
      case Connected():
        if (role == NearbyRole.host) {
          _guestEndpoint ??= event.peerId;
        } else {
          _hostEndpoint = event.peerId;
          unawaited(_send(event.peerId, {
            'type': NearbyProtocol.typeHello,
            'name': _localName,
            'protocol': protocolVersion,
          }));
        }
      case Disconnected():
        _handleDisconnect(event.peerId);
      case PayloadReceived():
        _onPayload(event.fromEndpointId, event.payload);
      case NearbyError():
        _patch(status: NearbyStatus.failed, note: event.message);
    }
  }

  Future<void> _acceptAsHost(String endpointId, String name) async {
    await _service.acceptConnection(endpointId);
    _guestEndpoint = endpointId;
    _patch(peerName: name, note: '$name connected!');
  }

  void _handleDisconnect(String peerId) {
    final relevant = peerId == _guestEndpoint || peerId == _hostEndpoint;
    if (!relevant || _disposed) return;
    _revealTimer?.cancel();
    _turnTimer?.cancel();
    _patch(status: NearbyStatus.failed, note: 'Player disconnected.');
  }

  // --- wire protocol --------------------------------------------------------

  void _onPayload(String from, Map<Object?, Object?> raw) {
    if (_disposed) return;
    final payload = Map<String, dynamic>.from(raw);
    switch (payload['type'] as String?) {
      case NearbyProtocol.typeHello:
        if (role == NearbyRole.host && from == _guestEndpoint) {
          final version = (payload['protocol'] as num?)?.toInt() ?? 0;
          if (version != protocolVersion) {
            _patch(
              status: NearbyStatus.failed,
              note: 'Your opponent runs a different Thinkr version.',
            );
            return;
          }
          _dealAndBroadcast();
        }
      case NearbyProtocol.typeSetup:
        if (role == NearbyRole.guest) {
          _setup = NearbySetup.fromMap(payload);
          _patterns
            ..clear()
            ..addAll([
              for (final p in payload['patterns'] as List? ?? const [])
                [
                  for (final c in (p as Map)['cells'] as List)
                    (c as num).toInt(),
                ],
            ]);
          _patch(
            status: NearbyStatus.connected,
            setup: _setup,
            peerName: 'Host',
            note: 'Get ready…',
          );
        }
      case NearbyProtocol.typePattern:
        if (role == NearbyRole.guest) _guestShowPattern(payload);
      case NearbyProtocol.typeTap:
        if (role == NearbyRole.host && from == _guestEndpoint) {
          _hostJudge((payload['cell'] as num).toInt(), byGuest: true);
        }
      case NearbyProtocol.typeCorrect:
        if (role == NearbyRole.guest) {
          _patch(found: {..._state.found, (payload['cell'] as num).toInt()});
        }
      case NearbyProtocol.typeWrong:
        if (role == NearbyRole.guest) {
          final cell = (payload['cell'] as num).toInt();
          _patch(errorCell: cell, errorStamp: _state.errorStamp + 1);
        }
      case NearbyProtocol.typeRound:
        if (role == NearbyRole.guest) {
          final hostWon = payload['hostWon'] == true;
          _patch(
            hostScore: (payload['hostScore'] as num).toInt(),
            guestScore: (payload['guestScore'] as num).toInt(),
            lastRoundWinner: hostWon ? 1 : 2,
            currentPlayer: hostWon ? 1 : 2,
            roundNumber: (payload['round'] as num).toInt(),
            phase: 'between',
            shown: const {},
            found: const {},
          );
        }
      case NearbyProtocol.typeDuelOver:
        if (role == NearbyRole.guest) {
          _patch(
            duelOver: true,
            summary: payload['summary'] as String? ?? 'Duel over',
            phase: 'done',
          );
        }
      case NearbyProtocol.typeRematch:
        _theirRematchVote = true;
        if (role == NearbyRole.guest) {
          _patch(rematchRequested: true, note: 'Host wants a rematch');
        }
        _maybeRematch();
      case NearbyProtocol.typeLeave:
        _handleDisconnect(from);
    }
  }

  Future<void> _send(String endpointId, Map<String, dynamic> payload) =>
      _service.send(endpointId, payload);

  // --- host: dealing + judging ----------------------------------------------

  void _dealAndBroadcast() {
    final seed = Random().nextInt(0x7fffffff);
    // Same ring-window deal shape as MemoryPuzzle, so the nearby duel feels
    // exactly like the pass-and-play one. Kept local to avoid a games/
    // import inside core/.
    const boardSize = 4;
    const cellsPerPattern = 4;
    final rng = Random(seed);
    final allCells = List.generate(boardSize * boardSize, (i) => i)
      ..shuffle(rng);
    _patterns
      ..clear()
      ..addAll([
        for (var p = 0; p < defaultRounds; p++)
          [
            for (var j = 0; j < cellsPerPattern; j++)
              allCells[(p * cellsPerPattern + j) % allCells.length],
          ],
      ]);
    _setup = NearbySetup(
      seed: seed,
      level: duelLevel,
      rounds: defaultRounds,
      boardSize: boardSize,
    );
    _currentPattern = 0;
    _hostSelection = {};

    unawaited(_send(_guestEndpoint!, {
      'type': NearbyProtocol.typeSetup,
      ..._setup!.toMap(),
      'patterns': [
        for (final p in _patterns) {'cells': p},
      ],
    }));
    _patch(status: NearbyStatus.connected, setup: _setup, roundNumber: 0);
    _hostStartPattern(0);
  }

  /// Host taps on its own turn.
  void hostTap(int cell) {
    if (role != NearbyRole.host) return;
    if (_state.phase != 'recall' || _state.currentPlayer != 1) return;
    _hostJudge(cell, byGuest: false);
  }

  void _hostJudge(int cell, {required bool byGuest}) {
    if (_disposed || _currentTarget.isEmpty) return;
    final correct = _currentTarget.contains(cell);
    if (correct) {
      _hostSelection.add(cell);
      if (!byGuest) _patch(found: {..._state.found, cell});
      unawaited(_send(_guestEndpoint!, {
        'type': NearbyProtocol.typeCorrect,
        'cell': cell,
      }));
      if (_hostSelection.length == _currentTarget.length) {
        _hostEndRound(winner: byGuest ? 2 : 1);
      }
    } else {
      if (!byGuest) {
        _patch(errorCell: cell, errorStamp: _state.errorStamp + 1);
      }
      unawaited(_send(_guestEndpoint!, {
        'type': NearbyProtocol.typeWrong,
        'cell': cell,
      }));
      _turnTimer?.cancel();
      _turnTimer = Timer(missPenalty, () {
        if (_disposed) return;
        _hostEndRound(winner: byGuest ? 1 : 2);
      });
    }
  }

  /// Host: reveal a pattern, then open recall for the current player.
  void _hostStartPattern(int index) {
    _currentPattern = index;
    _currentTarget = _patterns[index].toSet();
    _hostSelection = {};
    final isHostTurn = _state.currentPlayer == 1;

    _patch(
      phase: 'showing',
      shown: _currentTarget,
      found: const {},
      errorCell: null,
      lastRoundWinner: null,
      note: isHostTurn
          ? 'Your pattern — memorize'
          : "${_state.peerName ?? 'Player 2'}'s pattern",
    );

    unawaited(_send(_guestEndpoint!, {
      'type': NearbyProtocol.typePattern,
      'round': index + 1,
      'cells': _currentTarget.toList(),
      'turn': _state.currentPlayer,
    }));

    _revealTimer?.cancel();
    _revealTimer = Timer(revealWindow, () {
      if (_disposed) return;
      _patch(
        phase: 'recall',
        shown: const {},
        note: isHostTurn ? 'Rebuild it' : 'Waiting for Player 2…',
      );
    });
  }

  void _hostEndRound({required int winner}) {
    final hostWon = winner == 1;
    final hostScore = _state.hostScore + (hostWon ? 1 : 0);
    final guestScore = _state.guestScore + (hostWon ? 0 : 1);
    final roundNumber = _currentPattern + 1;

    _patch(
      phase: 'between',
      shown: const {},
      found: const {},
      hostScore: hostScore,
      guestScore: guestScore,
      currentPlayer: winner,
      lastRoundWinner: winner,
      roundNumber: roundNumber,
      note: hostWon
          ? 'You win the round!'
          : '${_state.peerName ?? 'Player 2'} wins the round!',
    );

    unawaited(_send(_guestEndpoint!, {
      'type': NearbyProtocol.typeRound,
      'round': roundNumber,
      'hostWon': hostWon,
      'hostScore': hostScore,
      'guestScore': guestScore,
    }));

    _turnTimer?.cancel();
    _turnTimer = Timer(roundBeat, () {
      if (_disposed) return;
      if (roundNumber >= (_setup?.rounds ?? defaultRounds)) {
        _hostFinish();
        return;
      }
      _patch(currentPlayer: winner == 1 ? 2 : 1);
      _hostStartPattern(roundNumber);
    });
  }

  void _hostFinish() {
    final h = _state.hostScore;
    final g = _state.guestScore;
    final summary = h == g
        ? "It's a draw — $h all."
        : 'Player ${h > g ? 1 : 2} wins $h–$g';
    _patch(duelOver: true, summary: summary, phase: 'done');
    unawaited(_send(_guestEndpoint!, {
      'type': NearbyProtocol.typeDuelOver,
      'summary': summary,
    }));
  }

  // --- guest: render what the host says --------------------------------------

  void _guestShowPattern(Map<String, dynamic> payload) {
    final cells = <int>{
      for (final c in payload['cells'] as List) (c as num).toInt(),
    };
    final turn = (payload['turn'] as num?)?.toInt() ?? 1;
    _patch(
      phase: 'showing',
      shown: cells,
      found: const {},
      errorCell: null,
      lastRoundWinner: null,
      currentPlayer: turn,
      roundNumber: (payload['round'] as num?)?.toInt() ?? _state.roundNumber,
      note: turn == 2 ? 'Your pattern — memorize' : "Host's pattern",
    );
    // Mirror the host's reveal window locally so the status line flips to
    // "Rebuild it" at the same moment the host opens recall.
    _revealTimer?.cancel();
    _revealTimer = Timer(revealWindow, () {
      if (_disposed) return;
      _patch(
        phase: 'recall',
        shown: const {},
        note: turn == 2 ? 'Rebuild it' : 'Waiting for host…',
      );
    });
  }

  /// Guest taps — sent to the host for judgement, never applied locally.
  void guestTap(int cell) {
    if (role != NearbyRole.guest) return;
    if (_state.phase != 'recall' || _state.currentPlayer != 2) return;
    final host = _hostEndpoint;
    if (host == null) return;
    unawaited(_send(host, {'type': NearbyProtocol.typeTap, 'cell': cell}));
  }

  // --- rematch ----------------------------------------------------------------

  void requestRematch() {
    _myRematchVote = true;
    final peer = role == NearbyRole.host ? _guestEndpoint : _hostEndpoint;
    if (peer != null) {
      unawaited(_send(peer, {'type': NearbyProtocol.typeRematch}));
    }
    if (role == NearbyRole.guest) {
      _patch(rematchRequested: true);
    }
    _maybeRematch();
  }

  void _maybeRematch() {
    if (!(_myRematchVote && _theirRematchVote)) return;
    _myRematchVote = false;
    _theirRematchVote = false;
    // Both sides reset scores; only the host re-deals — the guest's fresh
    // board arrives through the normal setup/pattern messages.
    _patch(
      duelOver: false,
      summary: null,
      rematchRequested: false,
      hostScore: 0,
      guestScore: 0,
      currentPlayer: 1,
      roundNumber: 0,
      lastRoundWinner: null,
      note: 'New duel!',
    );
    if (role == NearbyRole.host) {
      _dealAndBroadcast();
    }
  }

  // --- state plumbing ----------------------------------------------------------

  void _patch({
    NearbyStatus? status,
    String? note,
    NearbySetup? setup,
    String? peerName,
    List<NearbyPeer>? peers,
    String? phase,
    Set<int>? shown,
    Set<int>? found,
    int? errorCell,
    int? errorStamp,
    int? hostScore,
    int? guestScore,
    int? currentPlayer,
    int? roundNumber,
    int? lastRoundWinner,
    bool? duelOver,
    String? summary,
    bool? rematchRequested,
  }) {
    if (_disposed) return;
    // Built directly — NOT with copyWith keep-semantics — so that an
    // explicitly passed `null` (errorCell, lastRoundWinner) genuinely
    // clears the field, which the round transitions rely on.
    _state = NearbySessionState(
      status: status ?? _state.status,
      note: note ?? _state.note,
      setup: setup ?? _state.setup,
      peerName: peerName ?? _state.peerName,
      peers: peers ?? _state.peers,
      phase: phase ?? _state.phase,
      shown: shown ?? _state.shown,
      found: found ?? _state.found,
      errorCell: errorCell,
      errorStamp: errorStamp ?? _state.errorStamp,
      hostScore: hostScore ?? _state.hostScore,
      guestScore: guestScore ?? _state.guestScore,
      currentPlayer: currentPlayer ?? _state.currentPlayer,
      roundNumber: roundNumber ?? _state.roundNumber,
      lastRoundWinner: lastRoundWinner,
      duelOver: duelOver ?? _state.duelOver,
      summary: summary ?? _state.summary,
      rematchRequested: rematchRequested ?? _state.rematchRequested,
    );
    for (final listener in List.of(_listeners)) {
      listener(_state);
    }
  }
}
