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

  DiscoveredRoom({required this.ip, required this.roomName, required this.e2eeEnabled});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredRoom && ip == other.ip;

  @override
  int get hashCode => ip.hashCode;
}

class DiscoveryService {
  RawDatagramSocket? _udpSocket;
  final int _discoveryPort = 55555;
  Timer? _broadcastTimer;
  
  final _deviceDiscoveredController = StreamController<DiscoveredRoom>.broadcast();
  Stream<DiscoveredRoom> get onRoomDiscovered => _deviceDiscoveredController.stream;

  /// Starts listening for broadcasts from other LANLine apps
  Future<void> startListening() async {
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
    _udpSocket?.broadcastEnabled = true;

    _udpSocket?.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final datagram = _udpSocket?.receive();
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
              ));
            }
          } catch (_) {
            // Legacy plain-text broadcast fallback
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
  }

  /// Broadcasts our room's presence to the network
  Future<void> startBroadcasting({
    required String roomName,
    required bool e2eeEnabled,
  }) async {
    final ip = await getLocalIpAddress();
    _udpSocket ??= await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _udpSocket?.broadcastEnabled = true;

    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final payload = jsonEncode({
        'app': 'LANLINE',
        'room': roomName,
        'e2ee': e2eeEnabled,
        'ip': ip,
      });
      _udpSocket?.send(payload.codeUnits, InternetAddress('255.255.255.255'), _discoveryPort);
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
            fallbackIp = ip; // Link-local fallback
            continue;
          }
          if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
            return ip; // Highly probable correct LAN IP
          }
          fallbackIp ??= ip;
        }
      }
    }
    return fallbackIp;
  }

  void stop() {
    _broadcastTimer?.cancel();
    _udpSocket?.close();
    if (!_deviceDiscoveredController.isClosed) {
      _deviceDiscoveredController.close();
    }
  }
}
