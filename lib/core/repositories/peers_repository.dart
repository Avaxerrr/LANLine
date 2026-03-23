import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

class PeersRepository {
  final AppDatabase _database;
  final Uuid _uuid;

  PeersRepository(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  Future<PeerRow?> getPeerByPeerId(String peerId) {
    return (_database.select(
      _database.peersTable,
    )..where((tbl) => tbl.peerId.equals(peerId))).getSingleOrNull();
  }

  Future<PresenceRow?> getPresenceByPeerId(String peerId) {
    return (_database.select(
      _database.presenceTable,
    )..where((tbl) => tbl.peerId.equals(peerId))).getSingleOrNull();
  }

  Stream<List<PeerRow>> watchAcceptedContacts() {
    return (_database.select(_database.peersTable)
          ..where((tbl) => tbl.relationshipState.equals('accepted'))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.displayName)]))
        .watch();
  }

  Stream<List<PeerRow>> watchReachableAcceptedContacts() {
    final reachablePeerIds = _database.selectOnly(_database.presenceTable)
      ..addColumns([_database.presenceTable.peerId])
      ..where(_database.presenceTable.isReachable.equals(true));

    return (_database.select(_database.peersTable)
          ..where(
            (tbl) =>
                tbl.relationshipState.equals('accepted') &
                tbl.peerId.isInQuery(reachablePeerIds),
          )
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.displayName)]))
        .watch();
  }

  Stream<List<PeerRow>> watchDiscoveredPeers() {
    return (_database.select(_database.peersTable)
          ..where(
            (tbl) => tbl.relationshipState.isIn([
              'discovered',
              'pending_incoming',
              'pending_outgoing',
            ]),
          )
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.displayName)]))
        .watch();
  }

  Future<PeerRow> upsertPeer({
    required String peerId,
    required String displayName,
    String? deviceLabel,
    String? fingerprint,
    String relationshipState = 'discovered',
    bool isBlocked = false,
  }) async {
    final existing = await getPeerByPeerId(peerId);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (existing == null) {
      await _database
          .into(_database.peersTable)
          .insert(
            PeersTableCompanion.insert(
              id: _uuid.v4(),
              peerId: peerId,
              displayName: displayName,
              deviceLabel: drift.Value(deviceLabel),
              fingerprint: drift.Value(fingerprint),
              relationshipState: relationshipState,
              isBlocked: drift.Value(isBlocked),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      await (_database.update(
        _database.peersTable,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        PeersTableCompanion(
          displayName: drift.Value(displayName),
          deviceLabel: drift.Value(deviceLabel),
          fingerprint: drift.Value(fingerprint),
          relationshipState: drift.Value(relationshipState),
          isBlocked: drift.Value(isBlocked),
          updatedAt: drift.Value(now),
        ),
      );
    }

    return (await getPeerByPeerId(peerId))!;
  }

  Future<void> updateRelationshipState(
    String peerId,
    String relationshipState,
  ) async {
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

  Future<void> upsertPresence({
    required String peerId,
    required String status,
    required bool isReachable,
    String? transportType,
    String? host,
    int? port,
    int? lastHeartbeatAt,
    int? lastProbeAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (_database.select(
      _database.presenceTable,
    )..where((tbl) => tbl.peerId.equals(peerId))).getSingleOrNull();

    if (existing == null) {
      await _database
          .into(_database.presenceTable)
          .insert(
            PresenceTableCompanion.insert(
              id: _uuid.v4(),
              peerId: peerId,
              status: status,
              transportType: drift.Value(transportType),
              host: drift.Value(host),
              port: drift.Value(port),
              lastHeartbeatAt: drift.Value(lastHeartbeatAt),
              lastProbeAt: drift.Value(lastProbeAt),
              isReachable: drift.Value(isReachable),
              updatedAt: now,
            ),
          );
    } else {
      await (_database.update(
        _database.presenceTable,
      )..where((tbl) => tbl.id.equals(existing.id))).write(
        PresenceTableCompanion(
          status: drift.Value(status),
          transportType: drift.Value(transportType),
          host: drift.Value(host),
          port: drift.Value(port),
          lastHeartbeatAt: drift.Value(lastHeartbeatAt),
          lastProbeAt: drift.Value(lastProbeAt),
          isReachable: drift.Value(isReachable),
          updatedAt: drift.Value(now),
        ),
      );
    }

    await (_database.update(
      _database.peersTable,
    )..where((tbl) => tbl.peerId.equals(peerId))).write(
      PeersTableCompanion(
        lastSeenAt: drift.Value(lastHeartbeatAt ?? lastProbeAt),
        updatedAt: drift.Value(now),
      ),
    );
  }

  Future<List<PeerRow>> getPeersByPeerIds(List<String> peerIds) async {
    if (peerIds.isEmpty) return const [];
    return (_database.select(
      _database.peersTable,
    )..where((tbl) => tbl.peerId.isIn(peerIds))).get();
  }
}
