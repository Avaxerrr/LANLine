import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/network/discovery_service.dart';

void main() {
  group('DiscoveryService.buildBroadcastTargets', () {
    test('includes global and directed broadcasts for private LAN IPs', () {
      final targets = DiscoveryService.buildBroadcastTargets([
        '192.168.1.42',
        '10.0.0.8',
        '172.16.4.10',
      ]);

      expect(
        targets,
        containsAll([
          '255.255.255.255',
          '192.168.1.255',
          '10.0.0.255',
          '172.16.4.255',
        ]),
      );
    });

    test('skips loopback and link-local addresses', () {
      final targets = DiscoveryService.buildBroadcastTargets([
        '127.0.0.1',
        '169.254.10.20',
        '192.168.50.7',
      ]);

      expect(targets, contains('255.255.255.255'));
      expect(targets, contains('192.168.50.255'));
      expect(targets, isNot(contains('127.0.0.255')));
      expect(targets, isNot(contains('169.254.10.255')));
    });
  });

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
