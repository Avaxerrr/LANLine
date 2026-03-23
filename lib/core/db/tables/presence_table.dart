import 'package:drift/drift.dart';

@DataClassName('PresenceRow')
class PresenceTable extends Table {
  TextColumn get id => text()();
  TextColumn get peerId => text().named('peer_id')();
  TextColumn get status => text()();
  TextColumn get transportType => text().named('transport_type').nullable()();
  TextColumn get host => text().nullable()();
  IntColumn get port => integer().nullable()();
  IntColumn get lastHeartbeatAt =>
      integer().named('last_heartbeat_at').nullable()();
  IntColumn get lastProbeAt => integer().named('last_probe_at').nullable()();
  BoolColumn get isReachable =>
      boolean().named('is_reachable').withDefault(const Constant(false))();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
