import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/network/file_transfer_manager.dart';
import 'package:lanline/core/network/request_signaling_service.dart';
import 'package:lanline/core/providers/username_provider.dart';
import 'package:lanline/core/providers/security_providers.dart';
import 'package:lanline/core/providers/database_provider.dart';
import 'package:lanline/core/providers/identity_provider.dart';
import 'package:lanline/core/providers/file_transfer_protocol_provider.dart';
import 'package:lanline/core/providers/repository_providers.dart';
import 'package:lanline/core/security/device_signature_service.dart';
import 'package:lanline/core/security/in_memory_secret_store.dart';
import 'package:lanline/core/security/local_data_protection_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPeerSignalingService extends Mock
    implements RequestSignalingService {}

class MockFileTransferManager extends Mock implements FileTransferManager {}

class FakeHttpRequest extends Fake implements HttpRequest {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeHttpRequest());
  });

  group('FileTransferNotifier', () {
    late AppDatabase database;
    late MockPeerSignalingService signalingService;
    late StreamController<String> incomingMessages;
    late MockFileTransferManager fileTransferManager;
    late SharedPreferences prefs;
    late DeviceSignatureService signatureService;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      signalingService = MockPeerSignalingService();
      incomingMessages = StreamController<String>.broadcast();
      fileTransferManager = MockFileTransferManager();

      signatureService = DeviceSignatureService(InMemorySecretStore());
      SharedPreferences.setMockInitialValues({
        'lanline_username': 'Local User',
      });
      prefs = await SharedPreferences.getInstance();

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
      when(() => signalingService.registerHttpHandler(any())).thenReturn(null);
      when(
        () => signalingService.unregisterHttpHandler(any()),
      ).thenReturn(null);
      when(
        () => fileTransferManager.handleHttpRequest(any()),
      ).thenAnswer((_) async => false);
      when(() => fileTransferManager.cancelFile(any())).thenReturn(null);

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          requestSignalingServiceProvider.overrideWithValue(signalingService),
          fileTransferProvider.overrideWithValue(fileTransferManager),
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

    test(
      'sendFile stores a file message and attachment, then sends an offer',
      () async {
        final peersRepository = container.read(peersRepositoryProvider);
        final conversationsRepository = container.read(
          conversationsRepositoryProvider,
        );
        final messagesRepository = container.read(messagesRepositoryProvider);
        final attachmentsRepository = container.read(
          attachmentsRepositoryProvider,
        );

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
          port: RequestSignalingService.defaultPort,
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'lanline_media_test',
        );
        final file = File('${tempDir.path}\\report.txt');
        await file.writeAsString('hello from file');

        await container
            .read(fileTransferProtocolProvider.notifier)
            .sendFile(
              peerId: 'peer-remote',
              conversationId: 'conversation-remote',
              conversationTitle: 'Remote Device',
              filePath: file.path,
            );

        final conversation = await conversationsRepository
            .findDirectConversationByPeerId('peer-remote');
        final messages = await messagesRepository
            .watchMessages(conversation!.id)
            .first;
        final attachments = await attachmentsRepository
            .getAttachmentsByMessageId(messages.single.id);

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
            port: RequestSignalingService.defaultPort,
            payload: any(named: 'payload'),
          ),
        ).called(1);

        await tempDir.delete(recursive: true);
      },
    );

    test(
      'incoming file offer creates a conversation, message, and attachment',
      () async {
        await container.read(fileTransferProtocolProvider.notifier).start();

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

        final conversationsRepository = container.read(
          conversationsRepositoryProvider,
        );
        final messagesRepository = container.read(messagesRepositoryProvider);
        final attachmentsRepository = container.read(
          attachmentsRepositoryProvider,
        );

        final conversation = await conversationsRepository
            .findDirectConversationByPeerId('peer-remote');
        final messages = await messagesRepository
            .watchMessages(conversation!.id)
            .first;
        final attachments = await attachmentsRepository
            .getAttachmentsByMessageId('message-file-1');

        expect(conversation.unreadCount, 1);
        expect(messages, hasLength(1));
        expect(messages.single.type, 'file');
        expect(messages.single.textBody, 'photo.jpg');
        expect(attachments, hasLength(1));
        expect(attachments.single.id, 'attachment-file-1');
        expect(attachments.single.transferState, 'offered');
        expect(attachments.single.kind, 'image');
      },
    );

    test(
      'incoming file accept prepares an HTTP transfer and sends file_ready',
      () async {
        final peersRepository = container.read(peersRepositoryProvider);
        final conversationsRepository = container.read(
          conversationsRepositoryProvider,
        );
        final messagesRepository = container.read(messagesRepositoryProvider);
        final attachmentsRepository = container.read(
          attachmentsRepositoryProvider,
        );
        final localIdentity = await container
            .read(identityServiceProvider)
            .bootstrap();

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
          port: RequestSignalingService.defaultPort,
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'lanline_media_accept',
        );
        final file = File('${tempDir.path}\\report.txt');
        await file.writeAsString('hello from file');
        final conversation = await conversationsRepository
            .findOrCreateDirectConversation(
              localPeerId: localIdentity.peerId,
              peerId: 'peer-remote',
              title: 'Remote Device',
            );

        final message = await messagesRepository.insertMessage(
          conversationId: conversation.id,
          senderPeerId: localIdentity.peerId,
          type: 'file',
          textBody: 'report.txt',
          status: 'sent',
          sentAt: 1234567890,
        );
        await attachmentsRepository.insertAttachment(
          id: 'attachment-file-1',
          messageId: message.id,
          kind: 'file',
          fileName: 'report.txt',
          fileSize: await file.length(),
          mimeType: 'text/plain',
          localPath: file.path,
          transferState: 'awaiting_accept',
        );

        when(
          () => fileTransferManager.prepareOutgoingTransfer(
            attachmentId: 'attachment-file-1',
            filePath: file.path,
            fileName: 'report.txt',
            mimeType: 'text/plain',
          ),
        ).thenAnswer(
          (_) async => const PreparedFileTransfer(
            token: 'transfer-token-1',
            path: '/v2/media/files/transfer-token-1',
          ),
        );

        await container.read(fileTransferProtocolProvider.notifier).start();
        incomingMessages.add(
          jsonEncode({
            'protocol': 'lanline_v2_media',
            'action': 'file_accept',
            'senderPeerId': 'peer-remote',
            'senderDisplayName': 'Remote Device',
            'attachmentId': 'attachment-file-1',
          }),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));

        verify(
          () => fileTransferManager.prepareOutgoingTransfer(
            attachmentId: 'attachment-file-1',
            filePath: file.path,
            fileName: 'report.txt',
            mimeType: 'text/plain',
          ),
        ).called(1);
        verify(
          () => signalingService.sendMessage(
            host: '192.168.1.21',
            port: RequestSignalingService.defaultPort,
            payload: any(named: 'payload'),
          ),
        ).called(1);

        await tempDir.delete(recursive: true);
      },
    );

    test(
      'incoming file_ready downloads via HTTP transfer manager and marks complete',
      () async {
        final peersRepository = container.read(peersRepositoryProvider);
        final conversationsRepository = container.read(
          conversationsRepositoryProvider,
        );
        final messagesRepository = container.read(messagesRepositoryProvider);
        final attachmentsRepository = container.read(
          attachmentsRepositoryProvider,
        );
        final localIdentity = await container
            .read(identityServiceProvider)
            .bootstrap();

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
          port: RequestSignalingService.defaultPort,
        );

        final tempDir = await Directory.systemTemp.createTemp(
          'lanline_media_ready',
        );
        final downloadedFile = File('${tempDir.path}\\downloaded.txt');
        await downloadedFile.writeAsString('downloaded bytes');
        final conversation = await conversationsRepository
            .findOrCreateDirectConversation(
              localPeerId: localIdentity.peerId,
              peerId: 'peer-remote',
              title: 'Remote Device',
            );

        final message = await messagesRepository.insertMessage(
          id: 'message-file-1',
          clientGeneratedId: 'client-file-1',
          conversationId: conversation.id,
          senderPeerId: 'peer-remote',
          type: 'file',
          textBody: 'report.txt',
          status: 'delivered',
          sentAt: 1234567890,
        );
        await attachmentsRepository.insertAttachment(
          id: 'attachment-file-1',
          messageId: message.id,
          kind: 'file',
          fileName: 'report.txt',
          fileSize: 16,
          mimeType: 'text/plain',
          transferState: 'offered',
        );

        when(
          () => fileTransferManager.downloadFile(
            host: '192.168.1.21',
            port: RequestSignalingService.defaultPort,
            transferPath: '/v2/media/files/transfer-token-1',
            attachmentId: 'attachment-file-1',
            fileName: 'report.txt',
            onProgress: any(named: 'onProgress'),
            customTestSavePath: any(named: 'customTestSavePath'),
          ),
        ).thenAnswer((invocation) async {
          final progress =
              invocation.namedArguments[#onProgress]
                  as FileTransferProgressCallback?;
          progress?.call(8, 16);
          progress?.call(16, 16);
          return downloadedFile;
        });

        await container.read(fileTransferProtocolProvider.notifier).start();
        incomingMessages.add(
          jsonEncode({
            'protocol': 'lanline_v2_media',
            'action': 'file_ready',
            'senderPeerId': 'peer-remote',
            'senderDisplayName': 'Remote Device',
            'attachmentId': 'attachment-file-1',
            'transferToken': 'transfer-token-1',
            'transferPath': '/v2/media/files/transfer-token-1',
          }),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));

        final attachment = await attachmentsRepository.getAttachmentById(
          'attachment-file-1',
        );
        expect(attachment, isNotNull);
        expect(attachment!.transferState, 'completed');
        expect(attachment.localPath, downloadedFile.path);

        verify(
          () => fileTransferManager.downloadFile(
            host: '192.168.1.21',
            port: RequestSignalingService.defaultPort,
            transferPath: '/v2/media/files/transfer-token-1',
            attachmentId: 'attachment-file-1',
            fileName: 'report.txt',
            onProgress: any(named: 'onProgress'),
            customTestSavePath: any(named: 'customTestSavePath'),
          ),
        ).called(1);

        await tempDir.delete(recursive: true);
      },
    );
  });
}
