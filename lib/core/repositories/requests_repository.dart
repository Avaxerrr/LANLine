import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

class RequestsRepository {
  final AppDatabase _database;
  final Uuid _uuid;

  RequestsRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  Stream<List<ContactRequestRow>> watchPendingIncomingRequests() {
    return (_database.select(_database.contactRequestsTable)
          ..where(
            (tbl) =>
                tbl.direction.equals('incoming') & tbl.status.equals('pending'),
          )
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }

  Stream<List<ContactRequestRow>> watchPendingOutgoingRequests() {
    return (_database.select(_database.contactRequestsTable)
          ..where(
            (tbl) =>
                tbl.direction.equals('outgoing') & tbl.status.equals('pending'),
          )
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .watch();
  }

  Future<ContactRequestRow> createRequest({
    required String peerId,
    required String direction,
    String status = 'pending',
    String? message,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _database
        .into(_database.contactRequestsTable)
        .insert(
          ContactRequestsTableCompanion.insert(
            id: id,
            peerId: peerId,
            direction: direction,
            status: status,
            message: drift.Value(message),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (_database.select(
      _database.contactRequestsTable,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  Future<void> updateStatus(String requestId, String status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(
      _database.contactRequestsTable,
    )..where((tbl) => tbl.id.equals(requestId))).write(
      ContactRequestsTableCompanion(
        status: drift.Value(status),
        respondedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
  }
}
