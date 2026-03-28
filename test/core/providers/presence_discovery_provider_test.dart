import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/network/discovery_service.dart';
import 'package:lanline/core/network/request_signaling_service.dart';
import 'package:lanline/core/providers/presence_discovery_provider.dart';
import 'package:lanline/core/repositories/identity_repository.dart';
import 'package:lanline/core/repositories/conversations_repository.dart';
import 'package:lanline/core/repositories/peers_repository.dart';
import 'package:lanline/core/security/local_data_protection_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalDataProtectionService extends Mock
    implements LocalDataProtectionService {}

class MockDiscoveryService extends Mock implements DiscoveryService {}

class MockRequestSignalingService extends Mock
    implements RequestSignalingService {}

void main() {
  group('PresenceDiscoveryController', () {
    late AppDatabase database;
    late IdentityRepository identityRepository;
    late PeersRepository peersRepository;
    late ConversationsRepository conversationsRepository;
    late MockDiscoveryService discoveryService;
    late MockRequestSignalingService signalingService;
    late StreamController<DiscoveredPeerPresence> peerStream;
    late LocalIdentityRow localIdentity;
    late PresenceDiscoveryController controller;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      identityRepository = IdentityRepository(database);
      peersRepository = PeersRepository(database);
      final mockDataProtection = MockLocalDataProtectionService();
      when(() => mockDataProtection.encryptNullable(any()))
          .thenAnswer((inv) async => inv.positionalArguments[0] as String?);
      when(() => mockDataProtection.decryptNullable(any()))
          .thenAnswer((inv) async => inv.positionalArguments[0] as String?);
      conversationsRepository = ConversationsRepository(
        database,
        dataProtectionService: mockDataProtection,
      );
      discoveryService = MockDiscoveryService();
      signalingService = MockRequestSignalingService();
      peerStream = StreamController<DiscoveredPeerPresence>.broadcast();

      localIdentity = await identityRepository.createIdentity(
        id: 'local_identity',
        peerId: 'peer-local',
        displayName: 'Local Device',
        fingerprint: 'L0C4-LD',
      );

      when(
        () => discoveryService.onPeerPresenceDiscovered,
      ).thenAnswer((_) => peerStream.stream);
      when(() => discoveryService.startListening()).thenAnswer((_) async {});
      when(
        () => discoveryService.startPeerBroadcasting(
          peerId: localIdentity.peerId,
          displayName: localIdentity.displayName,
          deviceLabel: localIdentity.deviceLabel,
          fingerprint: localIdentity.fingerprint,
          isReachable: true,
          status: 'online',
          bindAddress: any(named: 'bindAddress'),
          transportType: any(named: 'transportType'),
          port: any(named: 'port'),
        ),
      ).thenAnswer((_) async {});
      when(() => discoveryService.stopPeerBroadcasting()).thenReturn(null);
      when(
        () => discoveryService.getLocalIpAddress(),
      ).thenAnswer((_) async => '192.168.1.20');
      when(
        () => signalingService.registerHttpHandler(any()),
      ).thenReturn(null);
      when(
        () => signalingService.unregisterHttpHandler(any()),
      ).thenReturn(null);

      controller = PresenceDiscoveryController(
        discoveryService: discoveryService,
        signalingService: signalingService,
        peersRepository: peersRepository,
        conversationsRepository: conversationsRepository,
        loadLocalIdentity: () async => localIdentity,
      );
    });

    tearDown(() async {
      await controller.dispose();
      await peerStream.close();
      await database.close();
    });

    test(
      'starts discovery and persists remote peer presence updates',
      () async {
        await controller.start();

        verify(() => discoveryService.startListening()).called(1);
        verify(
          () => discoveryService.startPeerBroadcasting(
            peerId: localIdentity.peerId,
            displayName: localIdentity.displayName,
            deviceLabel: localIdentity.deviceLabel,
            fingerprint: localIdentity.fingerprint,
            isReachable: true,
            status: 'online',
            bindAddress: '192.168.1.20',
            transportType: null,
            port: RequestSignalingService.defaultPort,
          ),
        ).called(1);

        peerStream.add(
          DiscoveredPeerPresence(
            peerId: 'peer-remote',
            displayName: 'Remote Device',
            deviceLabel: 'Tablet',
            fingerprint: 'R3M0-TE',
            ip: '192.168.1.21',
            status: 'online',
            isReachable: true,
            transportType: 'lan',
            lastHeartbeatAt: 1234567890,
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));

        final peer = await peersRepository.getPeerByPeerId('peer-remote');
        expect(peer, isNotNull);
        expect(peer!.displayName, 'Remote Device');
        expect(peer.deviceLabel, 'Tablet');
        expect(peer.fingerprint, 'R3M0-TE');
        expect(peer.relationshipState, 'discovered');
        expect(peer.isBlocked, isFalse);
        expect(peer.lastSeenAt, 1234567890);

        final presence = await (database.select(
          database.presenceTable,
        )..where((tbl) => tbl.peerId.equals('peer-remote'))).getSingle();
        expect(presence.status, 'online');
        expect(presence.isReachable, isTrue);
        expect(presence.transportType, 'lan');
        expect(presence.host, '192.168.1.21');
        expect(presence.lastHeartbeatAt, 1234567890);
      },
    );
  });
}
