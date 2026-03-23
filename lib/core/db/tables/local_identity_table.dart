import 'package:drift/drift.dart';

@DataClassName('LocalIdentityRow')
class LocalIdentityTable extends Table {
  TextColumn get id => text()();
  TextColumn get peerId => text().named('peer_id')();
  TextColumn get displayName => text().named('display_name')();
  TextColumn get deviceLabel => text().named('device_label').nullable()();
  TextColumn get fingerprint => text()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {peerId},
  ];
}
