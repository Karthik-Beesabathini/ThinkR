import 'dart:async';

import 'package:flutter/services.dart';

import 'nearby_connections_service.dart';

/// MethodChannel bridge to the Android Nearby Connections host.
///
/// Falls back to [MockNearbyConnectionsService] behavior (isAvailable ==
/// false, honest errors) when the platform implementation is missing —
/// e.g. running on iOS, desktop or an older Android without Google Play
/// services.
class MethodChannelNearbyService implements NearbyConnectionsService {
  MethodChannelNearbyService({
    this.channel = const MethodChannel('thinkr/nearby_connections'),
  });

  MethodChannel channel;

  void Function(NearbyEvent event)? _onEvent;

  @override
  Future<bool> isAvailable() async {
    try {
      return await channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      return await channel.invokeMethod<bool>('requestPermissions') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> start({
    required String serviceId,
    required String localName,
    required void Function(NearbyEvent event) onEvent,
  }) async {
    _onEvent = onEvent;
    channel.setMethodCallHandler(_handleCall);
    try {
      await channel.invokeMethod<void>('start', {
        'serviceId': serviceId,
        'localName': localName,
      });
    } on PlatformException catch (e) {
      onEvent(NearbyError(e.message ?? 'Failed to start nearby play.'));
    } on MissingPluginException {
      onEvent(const NearbyError(
        'Nearby play needs the Thinkr Android app (Google Play services).',
      ));
    }
  }

  @override
  Future<void> stop() async {
    channel.setMethodCallHandler(null);
    _onEvent = null;
    try {
      await channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Stopping a dead session is fine.
    } on MissingPluginException {
      // Same.
    }
  }

  @override
  Future<void> requestConnection(String endpointId, String token) async {
    try {
      await channel.invokeMethod<void>('requestConnection', {
        'endpointId': endpointId,
        'token': token,
      });
    } on PlatformException catch (e) {
      _onEvent?.call(NearbyError(e.message ?? 'Connection failed.'));
    } on MissingPluginException {
      _onEvent?.call(const NearbyError('Nearby play is unavailable here.'));
    }
  }

  @override
  Future<void> acceptConnection(String endpointId) async {
    try {
      await channel.invokeMethod<void>('acceptConnection', {
        'endpointId': endpointId,
        'endpointName': endpointId,
      });
    } on PlatformException catch (e) {
      _onEvent?.call(NearbyError(e.message ?? 'Accept failed.'));
    } on MissingPluginException {
      _onEvent?.call(const NearbyError('Nearby play is unavailable here.'));
    }
  }

  @override
  Future<void> send(String endpointId, Map<String, dynamic> payload) async {
    try {
      await channel.invokeMethod<void>('send', {
        'endpointId': endpointId,
        'payload': payload,
      });
    } on PlatformException {
      // Delivery failures surface as Disconnected events, not exceptions.
    } on MissingPluginException {
      // Unreachable in a real session.
    }
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'onPeerDiscovered':
        final args = call.arguments as Map<Object?, Object?>?;
        _onEvent?.call(PeerDiscovered(NearbyPeer(
          id: args?['endpointId'] as String? ?? '',
          name: args?['name'] as String? ?? 'Nearby player',
        )));
      case 'onPeerLost':
        _onEvent?.call(PeerLost(call.arguments['endpointId'] as String));
      case 'onConnectionInitiated':
        final args = call.arguments as Map<Object?, Object?>?;
        _onEvent?.call(ConnectionRequested(
          peerId: args?['endpointId'] as String? ?? '',
          name: args?['name'] as String? ?? 'Nearby player',
          token: args?['token'] as String? ?? '',
        ));
      case 'onConnected':
        _onEvent?.call(Connected(call.arguments['endpointId'] as String));
      case 'onDisconnected':
        _onEvent?.call(Disconnected(call.arguments['endpointId'] as String));
      case 'onPayloadReceived':
        final args = call.arguments as Map<Object?, Object?>?;
        final payload = args?['payload'];
        if (payload is Map) {
          _onEvent?.call(PayloadReceived(
            args?['endpointId'] as String? ?? '',
            Map<String, dynamic>.from(payload),
          ));
        }
      case 'onError':
        _onEvent?.call(
            NearbyError(call.arguments['message'] as String? ?? 'Nearby error.'));
    }
    return null;
  }
}
