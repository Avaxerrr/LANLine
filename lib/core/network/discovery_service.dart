import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService();
});

class DiscoveryService {
  RawDatagramSocket? _udpSocket;
  final int _discoveryPort = 55555;
  Timer? _broadcastTimer;
  
  // Stream to listen to other devices declaring their presence
  final _deviceDiscoveredController = StreamController<String>.broadcast();
  Stream<String> get onDeviceDiscovered => _deviceDiscoveredController.stream;

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
          if (message == 'LANLINE_DISCOVERY') {
            _deviceDiscoveredController.add(senderIp);
          }
        }
      }
    });
  }

  /// Broadcasts our presence out to the network
  Future<void> startBroadcasting() async {
    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final data = 'LANLINE_DISCOVERY'.codeUnits;
      _udpSocket?.send(data, InternetAddress('255.255.255.255'), _discoveryPort);
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
    _deviceDiscoveredController.close();
  }
}
