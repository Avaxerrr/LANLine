import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService();
});

/// Structured info about a room discovered on the LAN
class DiscoveredRoom {
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

class DiscoveryService {
  RawDatagramSocket? _listenSocket;
  RawDatagramSocket? _broadcastSocket;
  final int _discoveryPort = 55555;
  Timer? _broadcastTimer;
  StreamSubscription? _listenSubscription;
  
  // Re-creatable controller so it survives stop/start cycles
  StreamController<DiscoveredRoom> _deviceDiscoveredController = StreamController<DiscoveredRoom>.broadcast();
  Stream<DiscoveredRoom> get onRoomDiscovered => _deviceDiscoveredController.stream;

  /// Starts listening for broadcasts from other LANLine apps
  Future<void> startListening() async {
    // Don't double-bind
    if (_listenSocket != null) return;

    // Ensure the controller is open
    if (_deviceDiscoveredController.isClosed) {
      _deviceDiscoveredController = StreamController<DiscoveredRoom>.broadcast();
    }

    try {
      _listenSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: !Platform.isWindows, // reusePort not supported on Windows
      );
      _listenSocket?.broadcastEnabled = true;

      _listenSubscription = _listenSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenSocket?.receive();
          if (datagram != null) {
            final message = String.fromCharCodes(datagram.data);
            final senderIp = datagram.address.address;
            try {
              final data = jsonDecode(message);
              if (data['app'] == 'LANLINE') {
                _deviceDiscoveredController.add(DiscoveredRoom(
                  ip: data['ip'] ?? senderIp,
                  roomName: data['room'] ?? 'Unknown Room',
                  e2eeEnabled: data['e2ee'] ?? false,
                  port: data['port'] as int? ?? 55556,
                ));
              }
            } catch (_) {
              if (message == 'LANLINE_DISCOVERY') {
                _deviceDiscoveredController.add(DiscoveredRoom(
                  ip: senderIp,
                  roomName: 'LANLine Room',
                  e2eeEnabled: false,
                ));
              }
            }
          }
        }
      });
    } catch (e) {
      // Port already in use — ignore on hot reload
    }
  }

  /// Stop listening only (does NOT close the StreamController)
  void stopListening() {
    _listenSubscription?.cancel();
    _listenSubscription = null;
    _listenSocket?.close();
    _listenSocket = null;
  }

  /// Broadcasts our room's presence to the network
  Future<void> startBroadcasting({
    required String roomName,
    required bool e2eeEnabled,
    int port = 55556,
    String? bindAddress,
  }) async {
    // Use the explicit bind address if set, otherwise auto-detect
    final ip = bindAddress ?? await getLocalIpAddress();
    _broadcastSocket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _broadcastSocket?.broadcastEnabled = true;

    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final payload = jsonEncode({
        'app': 'LANLINE',
        'room': roomName,
        'e2ee': e2eeEnabled,
        'ip': ip,
        'port': port,
      });
      _broadcastSocket?.send(payload.codeUnits, InternetAddress('255.255.255.255'), _discoveryPort);
    });
  }

  /// Finds our own Local IP Address with smart filtering
  Future<String?> getLocalIpAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4, 
      includeLinkLocal: true,
    );
    String? fallbackIp;
    
    for (var interface in interfaces) {
      for (var address in interface.addresses) {
        if (!address.isLoopback) {
          final ip = address.address;
          if (ip.startsWith('169.254.')) {
            fallbackIp = ip;
            continue;
          }
          if (ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('100.')) {
            return ip;
          }
          fallbackIp ??= ip;
        }
      }
    }
    return fallbackIp;
  }

  /// Full stop — closes everything including the stream controller
  void stop() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    stopListening();
    _broadcastSocket?.close();
    _broadcastSocket = null;
    if (!_deviceDiscoveredController.isClosed) {
      _deviceDiscoveredController.close();
    }
  }
}
