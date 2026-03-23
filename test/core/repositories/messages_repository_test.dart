import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/repositories/attachments_repository.dart';
import 'package:lanline/core/repositories/conversations_repository.dart';
import 'package:lanline/core/repositories/messages_repository.dart';

void main() {
  late AppDatabase database;
  late ConversationsRepository conversationsRepository;
  late AttachmentsRepository attachmentsRepository;
  late MessagesRepository messagesRepository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    conversationsRepository = ConversationsRepository(database);
    attachmentsRepository = AttachmentsRepository(database);
    messagesRepository = MessagesRepository(
      database,
      conversationsRepository: conversationsRepository,
      attachmentsRepository: attachmentsRepository,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'deleteMessage removes message attachments and rolls preview back to previous message',
    () async {
      final conversation = await conversationsRepository
          .findOrCreateDirectConversation(
            localPeerId: 'local-peer',
            peerId: 'remote-peer',
            title: 'Remote',
          );

      final original = await messagesRepository.insertMessage(
        conversationId: conversation.id,
        senderPeerId: 'local-peer',
        type: 'text',
        textBody: 'first message',
        status: 'delivered',
      );
      final latest = await messagesRepository.insertMessage(
        conversationId: conversation.id,
        senderPeerId: 'remote-peer',
        type: 'text',
        textBody: 'second message',
        status: 'delivered',
      );
      await attachmentsRepository.insertAttachment(
        messageId: latest.id,
        kind: 'file',
        fileName: 'note.txt',
        fileSize: 12,
        transferState: 'completed',
      );

      await messagesRepository.deleteMessage(latest.id);

      final remainingMessages = await messagesRepository
          .watchMessages(conversation.id)
          .first;
      final deletedAttachments = await attachmentsRepository
          .getAttachmentsByMessageId(latest.id);
      final updatedConversation = await conversationsRepository
          .getConversationById(conversation.id);

      expect(remainingMessages.map((message) => message.id), [original.id]);
      expect(deletedAttachments, isEmpty);
      expect(updatedConversation?.lastMessagePreview, 'first message');
      expect(updatedConversation?.lastMessageAt, original.createdLocallyAt);
    },
  );

  test(
    'deleteMessage clears conversation preview when last message is removed',
    () async {
      final conversation = await conversationsRepository
          .findOrCreateDirectConversation(
            localPeerId: 'local-peer',
            peerId: 'remote-peer',
            title: 'Remote',
          );

      final onlyMessage = await messagesRepository.insertMessage(
        conversationId: conversation.id,
        senderPeerId: 'local-peer',
        type: 'text',
        textBody: 'only message',
        status: 'delivered',
      );

      await messagesRepository.deleteMessage(onlyMessage.id);

      final remainingMessages = await messagesRepository
          .watchMessages(conversation.id)
          .first;
      final updatedConversation = await conversationsRepository
          .getConversationById(conversation.id);

      expect(remainingMessages, isEmpty);
      expect(updatedConversation?.lastMessagePreview, isNull);
      expect(updatedConversation?.lastMessageAt, isNull);
    },
  );
}
