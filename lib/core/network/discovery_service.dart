import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService();
});

/// Structured info about a peer's live presence on the LAN.
class DiscoveredPeerPresence extends DiscoverySignal {
  final String peerId;
  final String displayName;
  final String? deviceLabel;
  final String? fingerprint;
  final String ip;
  final String status;
  final bool isReachable;
  final String transportType;
  final int? port;
  final int? lastHeartbeatAt;

  DiscoveredPeerPresence({
    required this.peerId,
    required this.displayName,
    required this.ip,
    required this.status,
    required this.isReachable,
    this.deviceLabel,
    this.fingerprint,
    this.transportType = 'lan',
    this.port,
    this.lastHeartbeatAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredPeerPresence &&
          peerId == other.peerId &&
          ip == other.ip &&
          transportType == other.transportType;

  @override
  int get hashCode => Object.hash(peerId, ip, transportType);
}

sealed class DiscoverySignal {
  const DiscoverySignal();
}

class DiscoveryService {
  RawDatagramSocket? _listenSocket;
  RawDatagramSocket? _broadcastSocket;
  final int _discoveryPort = 55555;
  Timer? _peerBroadcastTimer;
  StreamSubscription? _listenSubscription;

  StreamController<DiscoveredPeerPresence> _peerDiscoveredController =
      StreamController<DiscoveredPeerPresence>.broadcast();

  Stream<DiscoveredPeerPresence> get onPeerPresenceDiscovered =>
      _peerDiscoveredController.stream;

  /// Starts listening for broadcasts from other LANLine apps.
  Future<void> startListening() async {
    // Don't double-bind.
    if (_listenSocket != null) return;

    if (_peerDiscoveredController.isClosed) {
      _peerDiscoveredController =
          StreamController<DiscoveredPeerPresence>.broadcast();
    }

    try {
      _listenSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows,
      );
      _listenSocket?.broadcastEnabled = true;

      _listenSubscription = _listenSocket?.listen((RawSocketEvent event) {
        if (event != RawSocketEvent.read) return;

        final datagram = _listenSocket?.receive();
        if (datagram == null) return;

        final message = String.fromCharCodes(datagram.data);
        final senderIp = datagram.address.address;
        final signal = DiscoveryService.parseDiscoveryMessage(
          message,
          senderIp,
        );

        if (signal is DiscoveredPeerPresence) {
          _peerDiscoveredController.add(signal);
        }
      });
    } catch (error) {
      debugPrint(
        '[DiscoveryService] Failed to bind UDP listener on port '
        '$_discoveryPort: $error',
      );
    }
  }

  /// Stop listening only.
  void stopListening() {
    _listenSubscription?.cancel();
    _listenSubscription = null;
    _listenSocket?.close();
    _listenSocket = null;
  }

  /// Broadcasts live peer presence to the network.
  Future<void> startPeerBroadcasting({
    required String peerId,
    required String displayName,
    required bool isReachable,
    required String status,
    required String fingerprint,
    String? deviceLabel,
    String? transportType,
    int? port,
    String? bindAddress,
  }) async {
    _broadcastSocket ??= await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    _broadcastSocket?.broadcastEnabled = true;

    _peerBroadcastTimer?.cancel();
    _peerBroadcastTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(
        _broadcastPeerPresence(
          peerId: peerId,
          displayName: displayName,
          isReachable: isReachable,
          status: status,
          fingerprint: fingerprint,
          deviceLabel: deviceLabel,
          transportType: transportType,
          port: port,
          bindAddress: bindAddress,
        ),
      );
    });
    await _broadcastPeerPresence(
      peerId: peerId,
      displayName: displayName,
      isReachable: isReachable,
      status: status,
      fingerprint: fingerprint,
      deviceLabel: deviceLabel,
      transportType: transportType,
      port: port,
      bindAddress: bindAddress,
    );
  }

  void stopPeerBroadcasting() {
    _peerBroadcastTimer?.cancel();
    _peerBroadcastTimer = null;
    _closeBroadcastSocketIfIdle();
  }

  /// Finds our own local IP address with smart filtering.
  Future<String?> getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: true,
    );
    String? fallbackIp;

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback) continue;

        final ip = address.address;
        if (ip.startsWith('169.254.')) {
          fallbackIp = ip;
          continue;
        }
        if (ip.startsWith('192.168.') ||
            ip.startsWith('10.') ||
            ip.startsWith('100.')) {
          return ip;
        }
        fallbackIp ??= ip;
      }
    }

    return fallbackIp;
  }

  Future<void> _sendPayloadToBroadcastTargets(String payload) async {
    if (_broadcastSocket == null) return;

    final bytes = payload.codeUnits;
    final targets = await _resolveBroadcastTargets();

    for (final target in targets) {
      try {
        _broadcastSocket?.send(bytes, target, _discoveryPort);
      } catch (error) {
        debugPrint(
          '[DiscoveryService] Failed to broadcast to ${target.address}: '
          '$error',
        );
      }
    }
  }

  Future<void> _broadcastPeerPresence({
    required String peerId,
    required String displayName,
    required bool isReachable,
    required String status,
    required String fingerprint,
    String? deviceLabel,
    String? transportType,
    int? port,
    String? bindAddress,
  }) async {
    final ip = bindAddress ?? await getLocalIpAddress();
    final payload = jsonEncode({
      'app': 'LANLINE',
      'kind': 'peer_presence',
      'peerId': peerId,
      'displayName': displayName,
      'deviceLabel': deviceLabel,
      'fingerprint': fingerprint,
      'status': status,
      'isReachable': isReachable,
      'transportType': transportType ?? 'lan',
      'host': ip,
      'ip': ip,
      'port': port,
      'lastHeartbeatAt': DateTime.now().millisecondsSinceEpoch,
    });
    await _sendPayloadToBroadcastTargets(payload);
  }

  Future<List<InternetAddress>> _resolveBroadcastTargets() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: true,
    );

    final interfaceIps = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (address.isLoopback) continue;
        interfaceIps.add(address.address);
      }
    }

    final targets = buildBroadcastTargets(interfaceIps);
    return [
      for (final address in targets) InternetAddress(address),
    ];
  }

  /// Full stop - closes everything including the stream controllers.
  void stop() {
    _peerBroadcastTimer?.cancel();
    _peerBroadcastTimer = null;
    stopListening();
    _broadcastSocket?.close();
    _broadcastSocket = null;
    if (!_peerDiscoveredController.isClosed) {
      _peerDiscoveredController.close();
    }
  }

  void _closeBroadcastSocketIfIdle() {
    if (_peerBroadcastTimer == null) {
      _broadcastSocket?.close();
      _broadcastSocket = null;
    }
  }

  static DiscoverySignal? parseDiscoveryMessage(
    String message,
    String senderIp,
  ) {
    try {
      final data = jsonDecode(message);
      if (data is Map<String, dynamic> && data['app'] == 'LANLINE') {
        final kind = data['kind']?.toString();
        final hasPeerIdentity = data.containsKey('peerId');
        final transportType = data['transportType']?.toString() ?? 'lan';

        if (kind == 'peer_presence' || hasPeerIdentity) {
          final advertisedIp =
              data['host']?.toString() ?? data['ip']?.toString() ?? senderIp;
          final resolvedIp = transportType == 'lan' ? senderIp : advertisedIp;

          return DiscoveredPeerPresence(
            peerId: data['peerId']?.toString() ?? senderIp,
            displayName:
                data['displayName']?.toString() ??
                data['deviceLabel']?.toString() ??
                'Unknown Peer',
            deviceLabel: data['deviceLabel']?.toString(),
            fingerprint: data['fingerprint']?.toString(),
            ip: resolvedIp,
            status: data['status']?.toString() ?? 'online',
            isReachable: data['isReachable'] is bool
                ? data['isReachable'] as bool
                : true,
            transportType: transportType,
            port: data['port'] as int?,
            lastHeartbeatAt: data['lastHeartbeatAt'] as int?,
          );
        }
      }
    } catch (_) {}

    return null;
  }

  @visibleForTesting
  static Set<String> buildBroadcastTargets(Iterable<String> interfaceIps) {
    final targets = <String>{'255.255.255.255'};

    for (final ip in interfaceIps) {
      final directed = _deriveDirectedBroadcast(ip);
      if (directed != null) {
        targets.add(directed);
      }
    }

    return targets;
  }

  static String? _deriveDirectedBroadcast(String ip) {
    if (!_isLanCandidate(ip)) return null;

    final octets = ip.split('.');
    if (octets.length != 4) return null;

    return '${octets[0]}.${octets[1]}.${octets[2]}.255';
  }

  static bool _isLanCandidate(String ip) {
    if (ip.startsWith('169.254.') || ip.startsWith('127.')) {
      return false;
    }
    if (ip.startsWith('10.') || ip.startsWith('192.168.')) {
      return true;
    }

    final octets = ip.split('.');
    if (octets.length < 2) return false;

    final first = int.tryParse(octets[0]);
    final second = int.tryParse(octets[1]);
    if (first == null || second == null) return false;

    return first == 172 && second >= 16 && second <= 31;
  }
}
