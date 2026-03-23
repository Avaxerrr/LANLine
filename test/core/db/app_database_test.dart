import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/repositories/attachments_repository.dart';
import 'package:lanline/core/repositories/conversations_repository.dart';
import 'package:lanline/core/repositories/messages_repository.dart';
import 'package:lanline/core/repositories/peers_repository.dart';

void main() {
  late AppDatabase database;
  late PeersRepository peersRepository;
  late ConversationsRepository conversationsRepository;
  late AttachmentsRepository attachmentsRepository;
  late MessagesRepository messagesRepository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    peersRepository = PeersRepository(database);
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

  test('initial V2 tables are created and queryable', () async {
    final tables = await database
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();

    final names = tables
        .map((row) => row.data['name'] as String?)
        .whereType<String>()
        .toSet();

    expect(names, contains('local_identity_table'));
    expect(names, contains('peers_table'));
    expect(names, contains('presence_table'));
    expect(names, contains('contact_requests_table'));
    expect(names, contains('conversations_table'));
    expect(names, contains('conversation_members_table'));
    expect(names, contains('messages_table'));
    expect(names, contains('attachments_table'));
    expect(names, contains('outbox_table'));
  });

  test('can create direct conversation and persist messages locally', () async {
    await peersRepository.upsertPeer(
      peerId: 'peer-bob',
      displayName: 'Bob',
      relationshipState: 'accepted',
    );

    final conversation = await conversationsRepository
        .findOrCreateDirectConversation(
          localPeerId: 'local-peer',
          peerId: 'peer-bob',
        );

    final inserted = await messagesRepository.insertMessage(
      conversationId: conversation.id,
      senderPeerId: 'local-peer',
      type: 'text',
      textBody: 'hello Bob',
      status: 'pending',
    );

    final messages = await messagesRepository
        .watchMessages(conversation.id)
        .first;
    final conversations = await conversationsRepository
        .watchConversationList(localPeerId: 'local-peer')
        .first;

    expect(messages, hasLength(1));
    expect(messages.single.id, inserted.id);
    expect(messages.single.textBody, 'hello Bob');
    expect(conversations.single.lastMessagePreview, 'hello Bob');
    expect(conversations.single.type, 'direct');
  });
}
