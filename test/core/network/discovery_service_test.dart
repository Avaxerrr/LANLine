import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/network/discovery_service.dart';

void main() {
  group('DiscoveryService.parseDiscoveryMessage', () {
    test('parses legacy room broadcasts', () {
      final signal = DiscoveryService.parseDiscoveryMessage(
        jsonEncode({
          'app': 'LANLINE',
          'kind': 'room',
          'room': 'Studio',
          'e2ee': true,
          'ip': '192.168.1.20',
          'port': 55556,
        }),
        '192.168.1.20',
      );

      expect(signal, isA<DiscoveredRoom>());
      final room = signal as DiscoveredRoom;
      expect(room.roomName, 'Studio');
      expect(room.e2eeEnabled, isTrue);
      expect(room.ip, '192.168.1.20');
      expect(room.port, 55556);
    });

    test('parses peer presence broadcasts', () {
      final signal = DiscoveryService.parseDiscoveryMessage(
        jsonEncode({
          'app': 'LANLINE',
          'kind': 'peer_presence',
          'peerId': 'peer-123',
          'displayName': 'Alex',
          'deviceLabel': 'Laptop',
          'fingerprint': 'A1B2-C3',
          'status': 'online',
          'isReachable': true,
          'transportType': 'lan',
          'host': '192.168.1.21',
          'port': 55556,
          'lastHeartbeatAt': 1234567890,
        }),
        '192.168.1.21',
      );

      expect(signal, isA<DiscoveredPeerPresence>());
      final peer = signal as DiscoveredPeerPresence;
      expect(peer.peerId, 'peer-123');
      expect(peer.displayName, 'Alex');
      expect(peer.deviceLabel, 'Laptop');
      expect(peer.fingerprint, 'A1B2-C3');
      expect(peer.ip, '192.168.1.21');
      expect(peer.status, 'online');
      expect(peer.isReachable, isTrue);
      expect(peer.lastHeartbeatAt, 1234567890);
    });

    test('keeps plain legacy discovery fallback intact', () {
      final signal = DiscoveryService.parseDiscoveryMessage(
        'LANLINE_DISCOVERY',
        '192.168.1.22',
      );

      expect(signal, isA<DiscoveredRoom>());
      final room = signal as DiscoveredRoom;
      expect(room.roomName, 'LANLine Room');
      expect(room.ip, '192.168.1.22');
    });
  });
}
