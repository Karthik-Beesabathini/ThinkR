import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinkr/core/multiplayer/nearby_connections_service.dart';
import 'package:thinkr/core/multiplayer/nearby_host_session.dart';

/// Scriptable in-memory transport connecting a host session and a guest
/// session directly — no platform channel involved.
class _FakeNearbyService implements NearbyConnectionsService {
  _FakeNearbyService(this._id);

  final String _id;
  _FakeNearbyService? _peer;
  void Function(NearbyEvent)? _onEvent;
  final sent = <Map<String, dynamic>>[];

  static void pair(_FakeNearbyService a, _FakeNearbyService b) {
    a._peer = b;
    b._peer = a;
  }

  void emit(NearbyEvent event) => _onEvent?.call(event);

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> start({
    required String serviceId,
    required String localName,
    required void Function(NearbyEvent event) onEvent,
  }) {
    _onEvent = onEvent;
    return Future.value();
  }

  @override
  Future<void> stop() async {
    _onEvent = null;
  }

  @override
  Future<void> requestConnection(String endpointId, String token) async {}

  @override
  Future<void> acceptConnection(String endpointId) async {}

  @override
  Future<void> send(String endpointId, Map<String, dynamic> payload) async {
    sent.add(payload);
    _peer?._onEvent?.call(PayloadReceived(_id, payload));
  }
}

/// Session + recorder of the last pattern shown, pulled from state updates.
class _Player {
  _Player(this.session, List<NearbySessionState> sink) {
    session.addListener((s) {
      sink.add(s);
      if (s.phase == 'showing') _lastShown = s.shown;
    });
  }

  final NearbyHostSession session;
  Set<int> _lastShown = {};
  Set<int> get lastShown => _lastShown;
}

void _connect({
  required _FakeNearbyService hostService,
  required _FakeNearbyService guestService,
}) {
  hostService.emit(const Connected('g'));
  guestService.emit(const Connected('h'));
  hostService.emit(PayloadReceived('g', {
    'type': 'hello',
    'name': 'Guest phone',
    'protocol': 1,
  }));
}

(_Player, _Player) _setupPair() {
  final hostService = _FakeNearbyService('h');
  final guestService = _FakeNearbyService('g');
  _FakeNearbyService.pair(hostService, guestService);

  final hostSession = NearbyHostSession(
    service: hostService,
    role: NearbyRole.host,
    localName: 'Host phone',
  );
  final guestSession = NearbyHostSession(
    service: guestService,
    role: NearbyRole.guest,
    localName: 'Guest phone',
  );

  final host = _Player(hostSession, []);
  final guest = _Player(guestSession, []);

  hostSession.openLobby();
  guestSession.openLobby();
  _connect(hostService: hostService, guestService: guestService);
  return (host, guest);
}

void main() {
  test('connect → setup dealt with 6 rounds on a 4×4 board', () {
    fakeAsync((async) {
      final (host, guest) = _setupPair();
      async.elapse(const Duration(milliseconds: 10));

      expect(host.session.state.status, NearbyStatus.connected);
      expect(host.session.state.setup, isNotNull);
      expect(host.session.state.setup!.rounds, 6);
      expect(host.session.state.setup!.boardSize, 4);
      // Guest received the same setup.
      expect(guest.session.state.setup, isNotNull);
      expect(
        guest.session.state.setup!.seed,
        host.session.state.setup!.seed,
      );
      // First pattern is already showing.
      expect(host.session.state.phase, 'showing');
      expect(host.lastShown.length, 4);
    });
  });

  test('correct taps complete the round; wrong tap hands it over', () {
    fakeAsync((async) {
      final (host, guest) = _setupPair();
      // Wait for recall.
      while (host.session.state.phase != 'recall') {
        async.elapse(const Duration(milliseconds: 100));
      }
      final cells = host.lastShown.toList();

      // Host taps every cell correctly.
      for (final cell in cells) {
        host.session.hostTap(cell);
        async.elapse(const Duration(milliseconds: 10));
      }

      expect(host.session.state.lastRoundWinner, 1);
      expect(host.session.state.hostScore, 1);
      // Guest mirrored the round result.
      expect(guest.session.state.guestScore, 0);
      expect(guest.session.state.lastRoundWinner, 1);

      // Next round belongs to player 2 (the loser opens).
      async.elapse(const Duration(milliseconds: 1700));
      expect(host.session.state.currentPlayer, 2);
      expect(host.session.state.phase, 'showing');

      // Wait for guest recall, then guest taps a WRONG cell.
      while (guest.session.state.phase != 'recall') {
        async.elapse(const Duration(milliseconds: 100));
      }
      final shown = guest.lastShown;
      final wrong = [
        for (var i = 0; i < 16; i++) i,
      ].firstWhere((c) => !shown.contains(c));
      guest.session.guestTap(wrong);

      async.elapse(const Duration(milliseconds: 1000));
      // A miss gives the round to the other player.
      expect(host.session.state.lastRoundWinner, 1);
      expect(host.session.state.hostScore, 2);
      expect(host.session.state.guestScore, 0);
    });
  });

  test('full duel runs to completion and both sides see the summary', () {
    fakeAsync((async) {
      final (host, guest) = _setupPair();

      // Drive every round: the current tapper always taps the full pattern
      // correctly, so the winner of each round opens the next one.
      for (var round = 0; round < 6; round++) {
        final hostTurn = host.session.state.currentPlayer == 1;
        final tapper = hostTurn ? host : guest;
        while (tapper.session.state.phase != 'recall') {
          async.elapse(const Duration(milliseconds: 100));
        }
        for (final cell in tapper.lastShown.toList()) {
          if (hostTurn) {
            host.session.hostTap(cell);
          } else {
            guest.session.guestTap(cell);
          }
          async.elapse(const Duration(milliseconds: 10));
        }
        // Let the round beat play out into the next pattern.
        async.elapse(const Duration(milliseconds: 1700));
      }

      expect(host.session.state.duelOver, isTrue);
      expect(guest.session.state.duelOver, isTrue);
      // With the "loser opens next" rule and perfect play on both sides,
      // rounds alternate evenly — a fair draw. Both devices agree.
      expect(host.session.state.summary, "It's a draw — 3 all.");
      expect(guest.session.state.summary, "It's a draw — 3 all.");
    });
  });

  test('rematch needs both votes and resets the scores', () {
    fakeAsync((async) {
      final (host, guest) = _setupPair();
      // Fast-forward to a finished duel by winning all rounds.
      for (var round = 0; round < 6; round++) {
        final hostTurn = host.session.state.currentPlayer == 1;
        final tapper = hostTurn ? host : guest;
        while (tapper.session.state.phase != 'recall') {
          async.elapse(const Duration(milliseconds: 100));
        }
        for (final cell in tapper.lastShown.toList()) {
          if (hostTurn) {
            host.session.hostTap(cell);
          } else {
            guest.session.guestTap(cell);
          }
          async.elapse(const Duration(milliseconds: 10));
        }
        async.elapse(const Duration(milliseconds: 1700));
      }
      expect(host.session.state.duelOver, isTrue);

      // One vote alone changes nothing.
      host.session.requestRematch();
      expect(host.session.state.duelOver, isTrue);

      // The guest vote arrives; only then does the duel reset — host re-deals.
      guest.session.requestRematch();
      expect(host.session.state.duelOver, isFalse);
      expect(host.session.state.hostScore, 0);
      expect(host.session.state.guestScore, 0);
      expect(host.session.state.phase, 'showing');
      expect(guest.session.state.duelOver, isFalse);
      expect(guest.session.state.hostScore, 0);
    });
  });

  test('guest cannot tap during the host turn', () {
    fakeAsync((async) {
      final (host, guest) = _setupPair();
      while (host.session.state.phase != 'recall') {
        async.elapse(const Duration(milliseconds: 100));
      }
      // Host is player 1 and it is round 1 — guest taps must be dropped.
      for (final cell in guest.lastShown.toList()) {
        guest.session.guestTap(cell);
        async.elapse(const Duration(milliseconds: 10));
      }
      expect(host.session.state.found, isEmpty);
      expect(host.session.state.hostScore, 0);
    });
  });

  test('disconnect surfaces a failed state with a human note', () {
    fakeAsync((async) {
      final hostService = _FakeNearbyService('h');
      final guestService = _FakeNearbyService('g');
      _FakeNearbyService.pair(hostService, guestService);

      final hostSession = NearbyHostSession(
        service: hostService,
        role: NearbyRole.host,
      );
      final guestSession = NearbyHostSession(
        service: guestService,
        role: NearbyRole.guest,
      );
      hostSession.openLobby();
      guestSession.openLobby();
      _connect(hostService: hostService, guestService: guestService);

      expect(hostSession.state.status, NearbyStatus.connected);

      hostService.emit(const Disconnected('g'));
      expect(hostSession.state.status, NearbyStatus.failed);
      expect(hostSession.state.note, 'Player disconnected.');
    });
  });
}
