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

  Stream<List<ContactRequestWithPeer>> watchPendingIncomingRequestsWithNames() {
    return _watchRequestsWithNames('incoming');
  }

  Stream<List<ContactRequestWithPeer>> watchPendingOutgoingRequestsWithNames() {
    return _watchRequestsWithNames('outgoing');
  }

  Stream<List<ContactRequestWithPeer>> _watchRequestsWithNames(
    String direction,
  ) {
    final query = _database
        .select(_database.contactRequestsTable)
        .join([
          drift.leftOuterJoin(
            _database.peersTable,
            _database.peersTable.peerId.equalsExp(
              _database.contactRequestsTable.peerId,
            ),
          ),
        ])
      ..where(
        _database.contactRequestsTable.direction.equals(direction) &
            _database.contactRequestsTable.status.equals('pending'),
      )
      ..orderBy([
        drift.OrderingTerm.desc(_database.contactRequestsTable.createdAt),
      ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        final request = row.readTable(_database.contactRequestsTable);
        final peer = row.readTableOrNull(_database.peersTable);
        return ContactRequestWithPeer(
          request: request,
          displayName: peer?.displayName ?? request.peerId,
        );
      }).toList();
    });
  }

  Future<ContactRequestRow> createRequest({
    required String peerId,
    required String direction,
    String status = 'pending',
    String? message,
    String? id,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final requestId = id ?? _uuid.v4();
    final existing = await _findPendingRequest(
      peerId: peerId,
      direction: direction,
    );

    if (existing != null) {
      await _syncPeerRelationship(
        peerId: peerId,
        relationshipState: direction == 'incoming'
            ? 'pending_incoming'
            : 'pending_outgoing',
      );
      return existing;
    }

    await _database
        .into(_database.contactRequestsTable)
        .insert(
          ContactRequestsTableCompanion.insert(
            id: requestId,
            peerId: peerId,
            direction: direction,
            status: status,
            message: drift.Value(message),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await _syncPeerRelationship(
      peerId: peerId,
      relationshipState: direction == 'incoming'
          ? 'pending_incoming'
          : 'pending_outgoing',
    );

    return (_database.select(
      _database.contactRequestsTable,
    )..where((tbl) => tbl.id.equals(requestId))).getSingle();
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

  Future<ContactRequestRow> sendConnectionRequest({
    required String peerId,
    String? message,
    String? requestId,
  }) {
    return createRequest(
      peerId: peerId,
      direction: 'outgoing',
      message: message,
      id: requestId,
    );
  }

  Future<ContactRequestRow> receiveConnectionRequest({
    required String requestId,
    required String peerId,
    String? message,
  }) async {
    final existing = await getRequestById(requestId);
    if (existing != null) {
      return existing;
    }

    return createRequest(
      peerId: peerId,
      direction: 'incoming',
      message: message,
      id: requestId,
    );
  }

  Future<ContactRequestRow> acceptRequest(String requestId) async {
    final request = await _getRequestById(requestId);
    await updateStatus(requestId, 'accepted');
    await _syncPeerRelationship(
      peerId: request.peerId,
      relationshipState: 'accepted',
    );
    return _getRequestById(requestId);
  }

  Future<ContactRequestRow> declineRequest(String requestId) async {
    final request = await _getRequestById(requestId);
    await updateStatus(requestId, 'declined');
    await _syncPeerRelationship(
      peerId: request.peerId,
      relationshipState: 'discovered',
    );
    return _getRequestById(requestId);
  }

  Future<ContactRequestRow> cancelRequest(String requestId) async {
    final request = await _getRequestById(requestId);
    await updateStatus(requestId, 'cancelled');
    await _syncPeerRelationship(
      peerId: request.peerId,
      relationshipState: 'discovered',
    );
    return _getRequestById(requestId);
  }

  Future<void> blockPeer({required String peerId, String? requestId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (requestId != null) {
      await (_database.update(
        _database.contactRequestsTable,
      )..where((tbl) => tbl.id.equals(requestId))).write(
        ContactRequestsTableCompanion(
          status: const drift.Value('blocked'),
          respondedAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );
    }

    await _syncPeerRelationship(peerId: peerId, relationshipState: 'blocked');
  }

  Future<ContactRequestRow?> _findPendingRequest({
    required String peerId,
    required String direction,
  }) {
    return (_database.select(_database.contactRequestsTable)..where(
          (tbl) =>
              tbl.peerId.equals(peerId) &
              tbl.direction.equals(direction) &
              tbl.status.equals('pending'),
        ))
        .getSingleOrNull();
  }

  Future<ContactRequestRow?> getRequestById(String requestId) {
    return (_database.select(
      _database.contactRequestsTable,
    )..where((tbl) => tbl.id.equals(requestId))).getSingleOrNull();
  }

  Future<ContactRequestRow> _getRequestById(String requestId) async {
    return (_database.select(
      _database.contactRequestsTable,
    )..where((tbl) => tbl.id.equals(requestId))).getSingle();
  }

  Future<ContactRequestRow?> applyRemoteRequestStatus({
    required String requestId,
    required String peerId,
    required String status,
  }) async {
    final existing = await getRequestById(requestId);
    if (existing == null) return null;

    await updateStatus(requestId, status);

    final relationshipState = switch (status) {
      'accepted' => 'accepted',
      'blocked' => 'blocked',
      _ => 'discovered',
    };

    await _syncPeerRelationship(
      peerId: peerId,
      relationshipState: relationshipState,
    );

    return getRequestById(requestId);
  }

  Future<void> _syncPeerRelationship({
    required String peerId,
    required String relationshipState,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (_database.update(
      _database.peersTable,
    )..where((tbl) => tbl.peerId.equals(peerId))).write(
      PeersTableCompanion(
        relationshipState: drift.Value(relationshipState),
        isBlocked: drift.Value(relationshipState == 'blocked'),
        updatedAt: drift.Value(now),
      ),
    );
  }
}

class ContactRequestWithPeer {
  final ContactRequestRow request;
  final String displayName;

  const ContactRequestWithPeer({
    required this.request,
    required this.displayName,
  });
}
