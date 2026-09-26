import 'dart:async';

/// One discovered nearby player (peer).
class NearbyPeer {
  const NearbyPeer({required this.id, required this.name});

  /// Opaque endpoint id from the platform layer. Stable per discovery
  /// session; never persisted.
  final String id;

  /// Human-readable device name (already sanitized by the platform layer).
  final String name;

  @override
  bool operator ==(Object other) =>
      other is NearbyPeer && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// Connection lifecycle + message events for a nearby session.
sealed class NearbyEvent {
  const NearbyEvent();
}

/// Discovery found a peer.
class PeerDiscovered extends NearbyEvent {
  const PeerDiscovered(this.peer);
  final NearbyPeer peer;
}

/// A discovered peer disappeared (lost endpoint).
class PeerLost extends NearbyEvent {
  const PeerLost(this.peerId);
  final String peerId;
}

/// An outbound connection request was accepted.
class Connected extends NearbyEvent {
  const Connected(this.peerId);
  final String peerId;
}

/// A connection request arrived from an advertiser (initiator side only).
class ConnectionRequested extends NearbyEvent {
  const ConnectionRequested({
    required this.peerId,
    required this.name,
    required this.token,
  });
  final String peerId;
  final String name;
  final String token;
}

/// A peer disconnected.
class Disconnected extends NearbyEvent {
  const Disconnected(this.peerId);
  final String peerId;
}

/// A payload arrived. [payload] is a decoded JSON-compatible map.
class PayloadReceived extends NearbyEvent {
  const PayloadReceived(this.fromEndpointId, this.payload);
  final String fromEndpointId;
  final Map<Object?, Object?> payload;
}

/// The underlying platform reported a failure.
class NearbyError extends NearbyEvent {
  const NearbyError(this.message);
  final String message;
}

/// Contract for peer-to-peer discovery, connection and messaging.
///
/// Like [AdService] (core/ads), the SDK stays behind this interface: the
/// shipped implementation is a local mock, games never touch a plugin, and
/// a platform channel implementation can replace the mock without touching
/// gameplay code.
abstract interface class NearbyConnectionsService {
  /// True when this device can actually advertise/discover (platform
  /// channel available + permissions granted).
  Future<bool> isAvailable();

  /// Request the runtime permissions nearby play needs (location, and
  /// nearby devices on Android 12+). Returns true when all granted.
  Future<bool> requestPermissions();

  /// Start advertising (host) and/or discovery (guest). [serviceId] and
  /// [localName] identify the Thinkr session on the network.
  Future<void> start({
    required String serviceId,
    required String localName,
    required void Function(NearbyEvent event) onEvent,
  });

  /// Stop everything and release radios.
  Future<void> stop();

  /// Request a connection to a discovered peer (guest → host).
  Future<void> requestConnection(String endpointId, String token);

  /// Accept an incoming connection (host side).
  Future<void> acceptConnection(String endpointId);

  /// Send a JSON-compatible map to a connected peer.
  Future<void> send(String endpointId, Map<String, dynamic> payload);
}

/// Offline mock: two virtual "devices" inside one app for development and
/// tests, and a clean [NearbyError] everywhere else so the UI can explain
/// that nearby play needs a real platform build.
class MockNearbyConnectionsService implements NearbyConnectionsService {
  final _events = StreamController<NearbyEvent>.broadcast();
  bool _running = false;

  /// Test/dev hook: simulate the platform discovering a peer.
  void debugDiscovered(NearbyPeer peer) {
    if (!_running) return;
    _events.add(PeerDiscovered(peer));
  }

  /// Test/dev hook: simulate an incoming payload.
  void debugPayload(String fromEndpointId, Map<String, dynamic> payload) {
    if (!_running) return;
    _events.add(PayloadReceived(fromEndpointId, payload));
  }

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<void> start({
    required String serviceId,
    required String localName,
    required void Function(NearbyEvent event) onEvent,
  }) {
    _running = true;
    _sub = _events.stream.listen(onEvent);
    return Future.value();
  }

  StreamSubscription<NearbyEvent>? _sub;

  @override
  Future<void> stop() async {
    _running = false;
    await _sub?.cancel();
    _sub = null;
  }

  @override
  Future<void> requestConnection(String endpointId, String token) async {
    _events.add(const NearbyError('Nearby play needs a real device build.'));
  }

  @override
  Future<void> acceptConnection(String endpointId) async {
    _events.add(const NearbyError('Nearby play needs a real device build.'));
  }

  @override
  Future<void> send(String endpointId, Map<String, dynamic> payload) async {
    // Silent: a mock has nowhere to deliver.
  }
}
