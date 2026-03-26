import 'package:drift/drift.dart';

@DataClassName('PeerRow')
class PeersTable extends Table {
  TextColumn get id => text()();
  TextColumn get peerId => text().named('peer_id')();
  TextColumn get displayName => text().named('display_name')();
  TextColumn get deviceLabel => text().named('device_label').nullable()();
  TextColumn get fingerprint => text().nullable()();
  TextColumn get signingPublicKey =>
      text().named('signing_public_key').nullable()();
  BoolColumn get useTunnel =>
      boolean().named('use_tunnel').withDefault(const Constant(false))();
  TextColumn get tunnelHost => text().named('tunnel_host').nullable()();
  IntColumn get tunnelPort => integer().named('tunnel_port').nullable()();
  TextColumn get relationshipState => text().named('relationship_state')();
  BoolColumn get isBlocked =>
      boolean().named('is_blocked').withDefault(const Constant(false))();
  IntColumn get lastSeenAt => integer().named('last_seen_at').nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {peerId},
  ];
}
