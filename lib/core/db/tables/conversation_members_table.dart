import 'package:drift/drift.dart';

@DataClassName('ConversationMemberRow')
class ConversationMembersTable extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().named('conversation_id')();
  TextColumn get peerId => text().named('peer_id')();
  TextColumn get role => text()();
  IntColumn get joinedAt => integer().named('joined_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {conversationId, peerId},
  ];
}
