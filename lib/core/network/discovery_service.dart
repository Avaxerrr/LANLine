import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService();
});

/// Structured info about a room discovered on the LAN.
class DiscoveredRoom extends DiscoverySignal {
  final String ip;
  final String roomName;
  final bool e2eeEnabled;
  final int port;

  DiscoveredRoom({
    required this.ip,
    required this.roomName,
    required this.e2eeEnabled,
    this.port = 55556,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredRoom && ip == other.ip && port == other.port;

  @override
  int get hashCode => Object.hash(ip, port);
}

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
  Timer? _roomBroadcastTimer;
  Timer? _peerBroadcastTimer;
  StreamSubscription? _listenSubscription;

  // Re-creatable controllers so they survive stop/start cycles.
  StreamController<DiscoveredRoom> _roomDiscoveredController =
      StreamController<DiscoveredRoom>.broadcast();
  StreamController<DiscoveredPeerPresence> _peerDiscoveredController =
      StreamController<DiscoveredPeerPresence>.broadcast();

  Stream<DiscoveredRoom> get onRoomDiscovered =>
      _roomDiscoveredController.stream;
  Stream<DiscoveredPeerPresence> get onPeerPresenceDiscovered =>
      _peerDiscoveredController.stream;

  /// Starts listening for broadcasts from other LANLine apps.
  Future<void> startListening() async {
    // Don't double-bind.
    if (_listenSocket != null) return;

    // Ensure the controllers are open.
    if (_roomDiscoveredController.isClosed) {
      _roomDiscoveredController = StreamController<DiscoveredRoom>.broadcast();
    }
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

        if (signal is DiscoveredRoom) {
          _roomDiscoveredController.add(signal);
        } else if (signal is DiscoveredPeerPresence) {
          _peerDiscoveredController.add(signal);
        }
      });
    } catch (_) {
      // Port already in use or listener already active.
    }
  }

  /// Stop listening only.
  void stopListening() {
    _listenSubscription?.cancel();
    _listenSubscription = null;
    _listenSocket?.close();
    _listenSocket = null;
  }

  /// Broadcasts our room's presence to the network.
  Future<void> startBroadcasting({
    required String roomName,
    required bool e2eeEnabled,
    int port = 55556,
    String? bindAddress,
  }) async {
    final ip = bindAddress ?? await getLocalIpAddress();
    _broadcastSocket ??= await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    _broadcastSocket?.broadcastEnabled = true;

    _roomBroadcastTimer?.cancel();
    _roomBroadcastTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final payload = jsonEncode({
        'app': 'LANLINE',
        'kind': 'room',
        'room': roomName,
        'e2ee': e2eeEnabled,
        'ip': ip,
        'port': port,
      });
      _broadcastSocket?.send(
        payload.codeUnits,
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );
    });
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
    final ip = bindAddress ?? await getLocalIpAddress();
    _broadcastSocket ??= await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );
    _broadcastSocket?.broadcastEnabled = true;

    _peerBroadcastTimer?.cancel();
    _peerBroadcastTimer = Timer.periodic(const Duration(seconds: 5), (_) {
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
      _broadcastSocket?.send(
        payload.codeUnits,
        InternetAddress('255.255.255.255'),
        _discoveryPort,
      );
    });
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

  /// Full stop - closes everything including the stream controllers.
  void stop() {
    _roomBroadcastTimer?.cancel();
    _roomBroadcastTimer = null;
    _peerBroadcastTimer?.cancel();
    _peerBroadcastTimer = null;
    stopListening();
    _broadcastSocket?.close();
    _broadcastSocket = null;
    if (!_roomDiscoveredController.isClosed) {
      _roomDiscoveredController.close();
    }
    if (!_peerDiscoveredController.isClosed) {
      _peerDiscoveredController.close();
    }
  }

  void _closeBroadcastSocketIfIdle() {
    if (_roomBroadcastTimer == null && _peerBroadcastTimer == null) {
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

        if (kind == 'peer_presence' || hasPeerIdentity) {
          return DiscoveredPeerPresence(
            peerId: data['peerId']?.toString() ?? senderIp,
            displayName:
                data['displayName']?.toString() ??
                data['deviceLabel']?.toString() ??
                'Unknown Peer',
            deviceLabel: data['deviceLabel']?.toString(),
            fingerprint: data['fingerprint']?.toString(),
            ip: data['host']?.toString() ?? data['ip']?.toString() ?? senderIp,
            status: data['status']?.toString() ?? 'online',
            isReachable: data['isReachable'] is bool
                ? data['isReachable'] as bool
                : true,
            transportType: data['transportType']?.toString() ?? 'lan',
            port: data['port'] as int?,
            lastHeartbeatAt: data['lastHeartbeatAt'] as int?,
          );
        }

        if (kind == 'room' || data.containsKey('room')) {
          return DiscoveredRoom(
            ip: data['ip']?.toString() ?? senderIp,
            roomName: data['room']?.toString() ?? 'Unknown Room',
            e2eeEnabled: data['e2ee'] as bool? ?? false,
            port: data['port'] as int? ?? 55556,
          );
        }
      }
    } catch (_) {
      if (message == 'LANLINE_DISCOVERY') {
        return DiscoveredRoom(
          ip: senderIp,
          roomName: 'LANLine Room',
          e2eeEnabled: false,
        );
      }
    }

    return null;
  }
}
