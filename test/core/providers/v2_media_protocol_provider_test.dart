import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/network/v2_request_signaling_service.dart';
import 'package:lanline/core/providers/username_provider.dart';
import 'package:lanline/core/providers/security_providers.dart';
import 'package:lanline/core/providers/v2_database_provider.dart';
import 'package:lanline/core/providers/v2_media_protocol_provider.dart';
import 'package:lanline/core/providers/v2_repository_providers.dart';
import 'package:lanline/core/security/device_signature_service.dart';
import 'package:lanline/core/security/in_memory_secret_store.dart';
import 'package:lanline/core/security/local_data_protection_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockV2PeerSignalingService extends Mock
    implements V2RequestSignalingService {}

void main() {
  group('V2MediaProtocolNotifier', () {
    late AppDatabase database;
    late MockV2PeerSignalingService signalingService;
    late StreamController<String> incomingMessages;
    late SharedPreferences prefs;
    late DeviceSignatureService signatureService;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      signalingService = MockV2PeerSignalingService();
      incomingMessages = StreamController<String>.broadcast();

      signatureService = DeviceSignatureService(InMemorySecretStore());
      SharedPreferences.setMockInitialValues({
        'lanline_username': 'Local User',
      });
      prefs = await SharedPreferences.getInstance();

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

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          v2RequestSignalingServiceProvider.overrideWithValue(signalingService),
          deviceSignatureServiceProvider.overrideWithValue(signatureService),
          localDataProtectionServiceProvider.overrideWithValue(
            const PassthroughLocalDataProtectionService(),
          ),
        ],
      );

      addTearDown(container.dispose);
    });

    tearDown(() async {
      await incomingMessages.close();
      await database.close();
    });

    test('sendFile stores a file message and attachment, then sends an offer', () async {
      final peersRepository = container.read(peersRepositoryProvider);
      final conversationsRepository = container.read(conversationsRepositoryProvider);
      final messagesRepository = container.read(messagesRepositoryProvider);
      final attachmentsRepository = container.read(attachmentsRepositoryProvider);

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

      final tempDir = await Directory.systemTemp.createTemp('lanline_media_test');
      final file = File('${tempDir.path}\\report.txt');
      await file.writeAsString('hello from file');

      await container.read(v2MediaProtocolProvider.notifier).sendFile(
            peerId: 'peer-remote',
            conversationId: 'conversation-remote',
            conversationTitle: 'Remote Device',
            filePath: file.path,
          );

      final conversation = await conversationsRepository
          .findDirectConversationByPeerId('peer-remote');
      final messages = await messagesRepository.watchMessages(conversation!.id).first;
      final attachments = await attachmentsRepository.getAttachmentsByMessageId(
        messages.single.id,
      );

      expect(messages, hasLength(1));
      expect(messages.single.type, 'file');
      expect(messages.single.textBody, 'report.txt');
      expect(messages.single.status, 'sent');
      expect(attachments, hasLength(1));
      expect(attachments.single.fileName, 'report.txt');
      expect(attachments.single.transferState, 'awaiting_accept');
      expect(attachments.single.localPath, file.path);

      verify(
        () => signalingService.sendMessage(
          host: '192.168.1.21',
          port: V2RequestSignalingService.defaultPort,
          payload: any(named: 'payload'),
        ),
      ).called(1);

      await tempDir.delete(recursive: true);
    });

    test('incoming file offer creates a conversation, message, and attachment', () async {
      await container.read(v2MediaProtocolProvider.notifier).start();

      incomingMessages.add(
        jsonEncode({
          'protocol': 'lanline_v2_media',
          'action': 'file_offer',
          'senderPeerId': 'peer-remote',
          'senderDisplayName': 'Remote Device',
          'conversationId': 'conversation-remote',
          'messageId': 'message-file-1',
          'clientGeneratedId': 'client-file-1',
          'attachmentId': 'attachment-file-1',
          'fileName': 'photo.jpg',
          'fileSize': 4096,
          'mimeType': 'image/jpeg',
          'kind': 'image',
          'sentAt': 1234567890,
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final conversationsRepository = container.read(conversationsRepositoryProvider);
      final messagesRepository = container.read(messagesRepositoryProvider);
      final attachmentsRepository = container.read(attachmentsRepositoryProvider);

      final conversation = await conversationsRepository
          .findDirectConversationByPeerId('peer-remote');
      final messages = await messagesRepository.watchMessages(conversation!.id).first;
      final attachments = await attachmentsRepository.getAttachmentsByMessageId(
        'message-file-1',
      );

      expect(conversation.unreadCount, 1);
      expect(messages, hasLength(1));
      expect(messages.single.type, 'file');
      expect(messages.single.textBody, 'photo.jpg');
      expect(attachments, hasLength(1));
      expect(attachments.single.id, 'attachment-file-1');
      expect(attachments.single.transferState, 'offered');
      expect(attachments.single.kind, 'image');
    });

    test('incoming call start updates incoming call state', () async {
      await container.read(v2MediaProtocolProvider.notifier).start();

      incomingMessages.add(
        jsonEncode({
          'protocol': 'lanline_v2_media',
          'type': 'call_start',
          'senderPeerId': 'peer-remote',
          'senderDisplayName': 'Remote Device',
          'conversationId': 'conversation-remote',
          'callId': 'call-123',
          'callType': 'audio',
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(v2MediaProtocolProvider);
      expect(state.incomingCall, isNotNull);
      expect(state.incomingCall!.peerId, 'peer-remote');
      expect(state.incomingCall!.displayName, 'Remote Device');
      expect(state.incomingCall!.callId, 'call-123');
      expect(state.incomingCall!.callType, 'audio');
    });
  });
}
