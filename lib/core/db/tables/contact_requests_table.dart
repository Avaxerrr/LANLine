import 'package:drift/drift.dart';

@DataClassName('ContactRequestRow')
class ContactRequestsTable extends Table {
  TextColumn get id => text()();
  TextColumn get peerId => text().named('peer_id')();
  TextColumn get direction => text()();
  TextColumn get status => text()();
  TextColumn get message => text().nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get respondedAt => integer().named('responded_at').nullable()();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
