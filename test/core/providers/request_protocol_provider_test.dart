import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/identity/identity_service.dart';
import 'package:lanline/core/network/request_signaling_service.dart';
import 'package:lanline/core/providers/request_protocol_provider.dart';
import 'package:lanline/core/repositories/identity_repository.dart';
import 'package:lanline/core/repositories/peers_repository.dart';
import 'package:lanline/core/repositories/requests_repository.dart';
import 'package:lanline/core/security/device_signature_service.dart';
import 'package:lanline/core/security/in_memory_secret_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockRequestSignalingService extends Mock
    implements RequestSignalingService {}

void main() {
  group('RequestProtocolController', () {
    late AppDatabase database;
    late IdentityRepository identityRepository;
    late IdentityService identityService;
    late PeersRepository peersRepository;
    late RequestsRepository requestsRepository;
    late DeviceSignatureService signatureService;
    late DeviceSignatureService remoteSignatureService;
    late MockRequestSignalingService signalingService;
    late StreamController<String> incomingMessages;
    late RequestProtocolController controller;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      identityRepository = IdentityRepository(database);
      peersRepository = PeersRepository(database);
      requestsRepository = RequestsRepository(database);
      signalingService = MockRequestSignalingService();
      incomingMessages = StreamController<String>.broadcast();

      signatureService = DeviceSignatureService(InMemorySecretStore());
      remoteSignatureService = DeviceSignatureService(InMemorySecretStore());
      SharedPreferences.setMockInitialValues({
        IdentityService.legacyUsernameKey: 'Local User',
      });
      final prefs = await SharedPreferences.getInstance();
      identityService = IdentityService(
        repository: identityRepository,
        prefs: prefs,
        signatureService: signatureService,
      );

      when(() => signalingService.onMessageReceived)
          .thenAnswer((_) => incomingMessages.stream);
      when(
        () => signalingService.startServer(
          port: any(named: 'port'),
          bindAddress: any(named: 'bindAddress'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => signalingService.sendMessage(
          host: any(named: 'host'),
          port: any(named: 'port'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});
      when(() => signalingService.stopServer()).thenAnswer((_) async {});

      controller = RequestProtocolController(
        signalingService: signalingService,
        identityService: identityService,
        deviceSignatureService: signatureService,
        peersRepository: peersRepository,
        requestsRepository: requestsRepository,
      );
    });

    tearDown(() async {
      await controller.dispose();
      await incomingMessages.close();
      await database.close();
    });

    test('sendConnectionRequest sends to peer presence and stores outgoing row', () async {
      await identityService.bootstrap();
      await peersRepository.upsertPeer(
        peerId: 'peer-remote',
        displayName: 'Remote Device',
      );
      await peersRepository.upsertPresence(
        peerId: 'peer-remote',
        status: 'online',
        isReachable: true,
        transportType: 'lan',
        host: '192.168.1.21',
        port: RequestSignalingService.defaultPort,
      );

      final request = await controller.sendConnectionRequest(
        peerId: 'peer-remote',
        message: 'hello from local',
      );

      verify(
        () => signalingService.sendMessage(
          host: '192.168.1.21',
          port: RequestSignalingService.defaultPort,
          payload: any(named: 'payload'),
        ),
      ).called(1);

      final storedPeer = await peersRepository.getPeerByPeerId('peer-remote');
      expect(request.direction, 'outgoing');
      expect(request.status, 'pending');
      expect(request.peerId, 'peer-remote');
      expect(storedPeer?.relationshipState, 'pending_outgoing');
    });

    test('incoming request message creates pending incoming request', () async {
      await controller.start();
      final remoteIdentity = await remoteSignatureService.ensureIdentity();
      final payload = {
        'protocol': 'lanline_v2_request',
        'action': 'request',
        'requestId': 'req-123',
        'senderPeerId': 'peer-remote',
        'senderDisplayName': 'Remote Device',
        'senderDeviceLabel': 'Phone',
        'senderFingerprint': 'R3M0-TE',
        'message': 'connect with me',
      };

      incomingMessages.add(
        jsonEncode({
          ...payload,
          'senderSigningPublicKey': remoteIdentity.publicKey,
          'signature': await remoteSignatureService.signPayload(payload),
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final peer = await peersRepository.getPeerByPeerId('peer-remote');
      final requests = await requestsRepository.watchPendingIncomingRequests().first;

      expect(peer, isNotNull);
      expect(peer!.displayName, 'Remote Device');
      expect(peer.relationshipState, 'pending_incoming');
      expect(requests, hasLength(1));
      expect(requests.single.id, 'req-123');
      expect(requests.single.peerId, 'peer-remote');
    });

    test('remote accepted message updates outgoing request and peer state', () async {
      await controller.start();
      await peersRepository.upsertPeer(
        peerId: 'peer-remote',
        displayName: 'Remote Device',
      );
      await requestsRepository.sendConnectionRequest(
        peerId: 'peer-remote',
        requestId: 'req-456',
      );
      final remoteIdentity = await remoteSignatureService.ensureIdentity();
      final payload = {
        'protocol': 'lanline_v2_request',
        'action': 'accepted',
        'requestId': 'req-456',
        'senderPeerId': 'peer-remote',
        'senderDisplayName': 'Remote Device',
      };

      incomingMessages.add(
        jsonEncode({
          ...payload,
          'senderSigningPublicKey': remoteIdentity.publicKey,
          'signature': await remoteSignatureService.signPayload(payload),
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final request = await requestsRepository.getRequestById('req-456');
      final peer = await peersRepository.getPeerByPeerId('peer-remote');

      expect(request, isNotNull);
      expect(request!.status, 'accepted');
      expect(peer?.relationshipState, 'accepted');
    });
  });
}
