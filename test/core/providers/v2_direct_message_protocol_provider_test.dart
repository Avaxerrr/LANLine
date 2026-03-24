import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/identity/identity_service.dart';
import 'package:lanline/core/network/v2_request_signaling_service.dart';
import 'package:lanline/core/providers/v2_direct_message_protocol_provider.dart';
import 'package:lanline/core/repositories/attachments_repository.dart';
import 'package:lanline/core/repositories/conversations_repository.dart';
import 'package:lanline/core/repositories/identity_repository.dart';
import 'package:lanline/core/repositories/messages_repository.dart';
import 'package:lanline/core/repositories/peers_repository.dart';
import 'package:lanline/core/security/device_signature_service.dart';
import 'package:lanline/core/security/in_memory_secret_store.dart';
import 'package:lanline/core/security/local_data_protection_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockV2PeerSignalingService extends Mock
    implements V2RequestSignalingService {}

void main() {
  group('V2DirectMessageProtocolController', () {
    late AppDatabase database;
    late IdentityRepository identityRepository;
    late IdentityService identityService;
    late PeersRepository peersRepository;
    late ConversationsRepository conversationsRepository;
    late AttachmentsRepository attachmentsRepository;
    late MessagesRepository messagesRepository;
    late DeviceSignatureService signatureService;
    late DeviceSignatureService remoteSignatureService;
    late MockV2PeerSignalingService signalingService;
    late StreamController<String> incomingMessages;
    late V2DirectMessageProtocolController controller;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      identityRepository = IdentityRepository(database);
      peersRepository = PeersRepository(database);
      conversationsRepository = ConversationsRepository(
        database,
        dataProtectionService: const PassthroughLocalDataProtectionService(),
      );
      attachmentsRepository = AttachmentsRepository(database);
      messagesRepository = MessagesRepository(
        database,
        conversationsRepository: conversationsRepository,
        attachmentsRepository: attachmentsRepository,
        dataProtectionService: const PassthroughLocalDataProtectionService(),
        readRetentionLimit: () => 0,
      );
      signatureService = DeviceSignatureService(InMemorySecretStore());
      remoteSignatureService = DeviceSignatureService(InMemorySecretStore());
      signalingService = MockV2PeerSignalingService();
      incomingMessages = StreamController<String>.broadcast();

      SharedPreferences.setMockInitialValues({
        IdentityService.legacyUsernameKey: 'Local User',
      });
      final prefs = await SharedPreferences.getInstance();
      identityService = IdentityService(
        repository: identityRepository,
        prefs: prefs,
        signatureService: signatureService,
      );

      when(
        () => signalingService.onMessageReceived,
      ).thenAnswer((_) => incomingMessages.stream);
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

      controller = V2DirectMessageProtocolController(
        signalingService: signalingService,
        identityService: identityService,
        deviceSignatureService: signatureService,
        peersRepository: peersRepository,
        conversationsRepository: conversationsRepository,
        messagesRepository: messagesRepository,
      );
    });

    tearDown(() async {
      await controller.dispose();
      await incomingMessages.close();
      await database.close();
    });

    test(
      'sendTextMessage stores a local outgoing message and marks it sent',
      () async {
        await identityService.bootstrap();
        await peersRepository.upsertPeer(
          peerId: 'peer-remote',
          displayName: 'Remote Device',
          relationshipState: 'accepted',
        );
        await peersRepository.upsertPresence(
          peerId: 'peer-remote',
          status: 'online',
          isReachable: true,
          transportType: 'lan',
          host: '192.168.1.21',
          port: V2RequestSignalingService.defaultPort,
        );

        final message = await controller.sendTextMessage(
          peerId: 'peer-remote',
          text: 'Hello there',
          conversationTitle: 'Remote Device',
        );

        verify(
          () => signalingService.sendMessage(
            host: '192.168.1.21',
            port: V2RequestSignalingService.defaultPort,
            payload: any(named: 'payload'),
          ),
        ).called(1);

        final conversation = await conversationsRepository
            .findDirectConversationByPeerId('peer-remote');
        final messages = await messagesRepository
            .watchMessages(conversation!.id)
            .first;

        expect(message.status, 'sent');
        expect(conversation.title, 'Remote Device');
        expect(conversation.lastMessagePreview, 'Hello there');
        expect(messages, hasLength(1));
        expect(messages.single.textBody, 'Hello there');
        expect(messages.single.senderPeerId, isNot('peer-remote'));
      },
    );

    test('sendTextMessage preserves reply metadata', () async {
      await identityService.bootstrap();
      await peersRepository.upsertPeer(
        peerId: 'peer-remote',
        displayName: 'Remote Device',
        relationshipState: 'accepted',
      );
      await peersRepository.upsertPresence(
        peerId: 'peer-remote',
        status: 'online',
        isReachable: true,
        transportType: 'lan',
        host: '192.168.1.21',
        port: V2RequestSignalingService.defaultPort,
      );

      final conversation = await controller.openDirectConversation(
        peerId: 'peer-remote',
        title: 'Remote Device',
      );
      final original = await messagesRepository.insertMessage(
        conversationId: conversation.id,
        senderPeerId: 'peer-remote',
        type: 'text',
        textBody: 'Original message',
        status: 'delivered',
      );

      final reply = await controller.sendTextMessage(
        peerId: 'peer-remote',
        text: 'Reply message',
        conversationId: conversation.id,
        conversationTitle: 'Remote Device',
        replyToMessageId: original.id,
      );

      expect(reply.replyToMessageId, original.id);
    });

    test(
      'incoming text message creates a conversation, message, unread count, and ack',
      () async {
        await controller.start();
        await peersRepository.upsertPeer(
          peerId: 'peer-remote',
          displayName: 'Remote Device',
          relationshipState: 'accepted',
        );
        await peersRepository.upsertPresence(
          peerId: 'peer-remote',
          status: 'online',
          isReachable: true,
          transportType: 'lan',
          host: '192.168.1.21',
          port: V2RequestSignalingService.defaultPort,
        );

        final remoteIdentity = await remoteSignatureService.ensureIdentity();
        final payload = {
          'protocol': 'lanline_v2_message',
          'action': 'message',
          'senderPeerId': 'peer-remote',
          'senderDisplayName': 'Remote Device',
          'clientGeneratedId': 'msg-123',
          'type': 'text',
          'text': 'Hi from remote',
          'sentAt': 1234567890,
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
        final conversation = await conversationsRepository
            .findDirectConversationByPeerId('peer-remote');
        final messages = await messagesRepository
            .watchMessages(conversation!.id)
            .first;

        expect(peer, isNotNull);
        expect(peer!.displayName, 'Remote Device');
        expect(conversation.title, 'Remote Device');
        expect(conversation.unreadCount, 1);
        expect(messages, hasLength(1));
        expect(messages.single.textBody, 'Hi from remote');
        expect(messages.single.clientGeneratedId, 'msg-123');

        verify(
          () => signalingService.sendMessage(
            host: '192.168.1.21',
            port: V2RequestSignalingService.defaultPort,
            payload: any(named: 'payload'),
          ),
        ).called(1);
      },
    );

    test('incoming text message keeps reply metadata', () async {
      await controller.start();
      await peersRepository.upsertPeer(
        peerId: 'peer-remote',
        displayName: 'Remote Device',
        relationshipState: 'accepted',
      );

      final conversation = await conversationsRepository
          .findOrCreateDirectConversation(
            localPeerId: (await identityService.bootstrap()).peerId,
            peerId: 'peer-remote',
            title: 'Remote Device',
          );
      final original = await messagesRepository.insertMessage(
        conversationId: conversation.id,
        senderPeerId: 'peer-remote',
        type: 'text',
        textBody: 'Original',
        status: 'delivered',
        clientGeneratedId: 'seed-1',
      );

      await peersRepository.upsertPresence(
        peerId: 'peer-remote',
        status: 'online',
        isReachable: true,
        transportType: 'lan',
        host: '192.168.1.21',
        port: V2RequestSignalingService.defaultPort,
      );

      final remoteIdentity = await remoteSignatureService.ensureIdentity();
      final payload = {
        'protocol': 'lanline_v2_message',
        'action': 'message',
        'senderPeerId': 'peer-remote',
        'senderDisplayName': 'Remote Device',
        'clientGeneratedId': 'msg-reply',
        'type': 'text',
        'text': 'Reply body',
        'replyToMessageId': original.id,
        'sentAt': 1234567890,
      };
      incomingMessages.add(
        jsonEncode({
          ...payload,
          'senderSigningPublicKey': remoteIdentity.publicKey,
          'signature': await remoteSignatureService.signPayload(payload),
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final messages = await messagesRepository
          .watchMessages(conversation.id)
          .first;
      expect(messages.last.replyToMessageId, original.id);
    });

    test('ignores unsolicited direct messages from untrusted peers', () async {
      await controller.start();

      incomingMessages.add(
        jsonEncode({
          'protocol': 'lanline_v2_message',
          'action': 'message',
          'senderPeerId': 'unknown-peer',
          'senderDisplayName': 'Intruder',
          'clientGeneratedId': 'msg-rogue',
          'type': 'text',
          'text': 'Injected payload',
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final peer = await peersRepository.getPeerByPeerId('unknown-peer');
      final conversations = await conversationsRepository
          .watchConversationList(
            localPeerId: (await identityService.bootstrap()).peerId,
          )
          .first;

      expect(peer, isNull);
      expect(conversations, isEmpty);
      verifyNever(
        () => signalingService.sendMessage(
          host: any(named: 'host'),
          port: any(named: 'port'),
          payload: any(named: 'payload'),
        ),
      );
    });
  });
}
