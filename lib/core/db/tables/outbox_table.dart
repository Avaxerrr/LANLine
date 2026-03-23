import 'package:drift/drift.dart';

@DataClassName('OutboxRow')
class OutboxTable extends Table {
  TextColumn get id => text()();
  TextColumn get messageId => text().named('message_id')();
  TextColumn get peerId => text().named('peer_id')();
  IntColumn get attemptCount =>
      integer().named('attempt_count').withDefault(const Constant(0))();
  IntColumn get nextRetryAt => integer().named('next_retry_at').nullable()();
  TextColumn get lastError => text().named('last_error').nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
