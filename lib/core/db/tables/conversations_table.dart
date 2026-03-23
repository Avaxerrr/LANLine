import 'package:drift/drift.dart';

@DataClassName('ConversationRow')
class ConversationsTable extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get title => text().nullable()();
  TextColumn get lastMessagePreview =>
      text().named('last_message_preview').nullable()();
  IntColumn get lastMessageAt =>
      integer().named('last_message_at').nullable()();
  IntColumn get unreadCount =>
      integer().named('unread_count').withDefault(const Constant(0))();
  BoolColumn get isArchived =>
      boolean().named('is_archived').withDefault(const Constant(false))();
  BoolColumn get isMuted =>
      boolean().named('is_muted').withDefault(const Constant(false))();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
