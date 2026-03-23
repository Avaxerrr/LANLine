import 'package:drift/drift.dart';

@DataClassName('MessageRow')
class MessagesTable extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().named('conversation_id')();
  TextColumn get senderPeerId => text().named('sender_peer_id')();
  TextColumn get clientGeneratedId => text().named('client_generated_id')();
  TextColumn get type => text()();
  TextColumn get textBody => text().named('text_body').nullable()();
  TextColumn get status => text()();
  TextColumn get replyToMessageId =>
      text().named('reply_to_message_id').nullable()();
  TextColumn get metadataJson => text().named('metadata_json').nullable()();
  IntColumn get sentAt => integer().named('sent_at').nullable()();
  IntColumn get receivedAt => integer().named('received_at').nullable()();
  IntColumn get readAt => integer().named('read_at').nullable()();
  IntColumn get createdLocallyAt => integer().named('created_locally_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {clientGeneratedId},
  ];
}
