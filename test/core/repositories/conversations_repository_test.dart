import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/repositories/conversations_repository.dart';
import 'package:lanline/core/security/local_data_protection_service.dart';

void main() {
  late AppDatabase database;
  late ConversationsRepository conversationsRepository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    conversationsRepository = ConversationsRepository(
      database,
      dataProtectionService: const PassthroughLocalDataProtectionService(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('pinMessage stores a pinned message id on the conversation', () async {
    final conversation = await conversationsRepository
        .findOrCreateDirectConversation(
          localPeerId: 'local-peer',
          peerId: 'remote-peer',
          title: 'Remote',
        );

    await conversationsRepository.pinMessage(
      conversationId: conversation.id,
      messageId: 'message-123',
    );

    final updated = await conversationsRepository.getConversationById(
      conversation.id,
    );
    expect(updated?.pinnedMessageId, 'message-123');
  });

  test('clearPinnedMessage removes the pinned message id', () async {
    final conversation = await conversationsRepository
        .findOrCreateDirectConversation(
          localPeerId: 'local-peer',
          peerId: 'remote-peer',
          title: 'Remote',
        );

    await conversationsRepository.pinMessage(
      conversationId: conversation.id,
      messageId: 'message-123',
    );
    await conversationsRepository.clearPinnedMessage(conversation.id);

    final updated = await conversationsRepository.getConversationById(
      conversation.id,
    );
    expect(updated?.pinnedMessageId, isNull);
  });
}
