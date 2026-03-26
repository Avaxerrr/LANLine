import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../security/local_data_protection_service.dart';

class ConversationsRepository {
  final AppDatabase _database;
  final LocalDataProtectionService _dataProtectionService;
  final Uuid _uuid;

  ConversationsRepository(
    this._database, {
    required LocalDataProtectionService dataProtectionService,
    Uuid? uuid,
  }) : _dataProtectionService = dataProtectionService,
       _uuid = uuid ?? const Uuid();

  Stream<List<ConversationRow>> watchConversationList({
    required String localPeerId,
  }) {
    final visibleConversationIds =
        _database.selectOnly(_database.conversationMembersTable)
          ..addColumns([_database.conversationMembersTable.conversationId])
          ..where(
            _database.conversationMembersTable.peerId.equals(localPeerId) &
                _database.conversationMembersTable.role.isNotValue('invited'),
          );

    return (_database.select(_database.conversationsTable)
          ..where((tbl) => tbl.id.isInQuery(visibleConversationIds))
          ..orderBy([
            (tbl) => drift.OrderingTerm.desc(tbl.lastMessageAt),
            (tbl) => drift.OrderingTerm.desc(tbl.updatedAt),
          ]))
        .watch()
        .asyncMap((rows) async => Future.wait(rows.map(_decryptConversation)));
  }

  Stream<ConversationRow?> watchConversationById(String conversationId) {
    return (_database.select(_database.conversationsTable)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .watchSingleOrNull()
        .asyncMap(
          (row) async => row == null ? null : _decryptConversation(row),
        );
  }

  Stream<List<ConversationRow>> watchPendingGroupInvites({
    required String localPeerId,
  }) {
    final inviteIds = _database.selectOnly(_database.conversationMembersTable)
      ..addColumns([_database.conversationMembersTable.conversationId])
      ..where(
        _database.conversationMembersTable.peerId.equals(localPeerId) &
            _database.conversationMembersTable.role.equals('invited'),
      );

    return (_database.select(_database.conversationsTable)
          ..where(
            (tbl) => tbl.id.isInQuery(inviteIds) & tbl.type.equals('group'),
          )
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.updatedAt)]))
        .watch()
        .asyncMap((rows) async => Future.wait(rows.map(_decryptConversation)));
  }

  Stream<List<ConversationMemberRow>> watchConversationMembers(
    String conversationId,
  ) {
    return (_database.select(_database.conversationMembersTable)
          ..where((tbl) => tbl.conversationId.equals(conversationId))
          ..orderBy([
            (tbl) => drift.OrderingTerm.asc(tbl.role),
            (tbl) => drift.OrderingTerm.asc(tbl.joinedAt),
          ]))
        .watch();
  }

  Future<ConversationRow?> getConversationById(String conversationId) {
    return (_database.select(_database.conversationsTable)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .getSingleOrNull()
        .then((row) => row == null ? null : _decryptConversation(row));
  }

  Future<ConversationMemberRow?> getMembership({
    required String conversationId,
    required String peerId,
  }) {
    return (_database.select(_database.conversationMembersTable)..where(
          (tbl) =>
              tbl.conversationId.equals(conversationId) &
              tbl.peerId.equals(peerId),
        ))
        .getSingleOrNull();
  }

  Future<List<ConversationMemberRow>> getConversationMembers(
    String conversationId,
  ) {
    return (_database.select(_database.conversationMembersTable)
          ..where((tbl) => tbl.conversationId.equals(conversationId))
          ..orderBy([
            (tbl) => drift.OrderingTerm.asc(tbl.role),
            (tbl) => drift.OrderingTerm.asc(tbl.joinedAt),
          ]))
        .get();
  }

  Future<List<String>> getMessageTargetPeerIds({
    required String conversationId,
    required String localPeerId,
  }) async {
    final members =
        await (_database.select(_database.conversationMembersTable)..where(
              (tbl) =>
                  tbl.conversationId.equals(conversationId) &
                  tbl.peerId.isNotValue(localPeerId) &
                  tbl.role.isIn(['admin', 'member']),
            ))
            .get();
    return members.map((member) => member.peerId).toList();
  }

  Future<ConversationRow?> findDirectConversationByPeerId(String peerId) async {
    final members = await (_database.select(
      _database.conversationMembersTable,
    )..where((tbl) => tbl.peerId.equals(peerId))).get();

    for (final member in members) {
      final conversation =
          await (_database.select(_database.conversationsTable)..where(
                (tbl) =>
                    tbl.id.equals(member.conversationId) &
                    tbl.type.equals('direct'),
              ))
              .getSingleOrNull();
      if (conversation != null) {
        return conversation;
      }
    }

    return null;
  }

  Future<ConversationRow> findOrCreateDirectConversation({
    required String localPeerId,
    required String peerId,
    String? title,
  }) async {
    final existing = await findDirectConversationByPeerId(peerId);
    if (existing != null) {
      if (title != null && title.isNotEmpty && existing.title != title) {
        await updateConversationTitle(
          conversationId: existing.id,
          title: title,
        );
        return (await getConversationById(existing.id))!;
      }
      return existing;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final conversationId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.conversationsTable)
          .insert(
            ConversationsTableCompanion.insert(
              id: conversationId,
              type: 'direct',
              title: drift.Value(title),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _database
          .into(_database.conversationMembersTable)
          .insert(
            ConversationMembersTableCompanion.insert(
              id: _uuid.v4(),
              conversationId: conversationId,
              peerId: localPeerId,
              role: 'member',
              joinedAt: now,
            ),
          );

      await _database
          .into(_database.conversationMembersTable)
          .insert(
            ConversationMembersTableCompanion.insert(
              id: _uuid.v4(),
              conversationId: conversationId,
              peerId: peerId,
              role: 'member',
              joinedAt: now,
            ),
          );
    });

    return (await getConversationById(conversationId))!;
  }

  Future<ConversationRow> createGroupConversation({
    String? conversationId,
    required String localPeerId,
    required String title,
    required List<String> invitedPeerIds,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = conversationId ?? _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.conversationsTable)
          .insertOnConflictUpdate(
            ConversationsTableCompanion.insert(
              id: id,
              type: 'group',
              title: drift.Value(title),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _upsertConversationMember(
        conversationId: id,
        peerId: localPeerId,
        role: 'admin',
        joinedAt: now,
      );

      for (final peerId in invitedPeerIds) {
        await _upsertConversationMember(
          conversationId: id,
          peerId: peerId,
          role: 'invited',
          joinedAt: now,
        );
      }
    });

    return (await getConversationById(id))!;
  }

  Future<ConversationRow> upsertIncomingGroupConversation({
    required String conversationId,
    required String title,
    required List<GroupConversationMemberSeed> members,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _database.transaction(() async {
      final existing = await getConversationById(conversationId);
      if (existing == null) {
        await _database
            .into(_database.conversationsTable)
            .insert(
              ConversationsTableCompanion.insert(
                id: conversationId,
                type: 'group',
                title: drift.Value(title),
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else if (existing.title != title) {
        await updateConversationTitle(
          conversationId: conversationId,
          title: title,
        );
      }

      for (final member in members) {
        await _upsertConversationMember(
          conversationId: conversationId,
          peerId: member.peerId,
          role: member.role,
          joinedAt: member.joinedAt ?? now,
        );
      }
    });

    return (await getConversationById(conversationId))!;
  }

  Future<void> updateMemberRole({
    required String conversationId,
    required String peerId,
    required String role,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(_database.conversationMembersTable)..where(
          (tbl) =>
              tbl.conversationId.equals(conversationId) &
              tbl.peerId.equals(peerId),
        ))
        .write(
          ConversationMembersTableCompanion(
            role: drift.Value(role),
            joinedAt: drift.Value(now),
          ),
        );

    await (_database.update(_database.conversationsTable)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .write(ConversationsTableCompanion(updatedAt: drift.Value(now)));
  }

  Future<void> removeMember({
    required String conversationId,
    required String peerId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.delete(_database.conversationMembersTable)..where(
          (tbl) =>
              tbl.conversationId.equals(conversationId) &
              tbl.peerId.equals(peerId),
        ))
        .go();

    await (_database.update(_database.conversationsTable)
          ..where((tbl) => tbl.id.equals(conversationId)))
        .write(ConversationsTableCompanion(updatedAt: drift.Value(now)));
  }

  Future<void> deleteConversation(String conversationId) async {
    await _database.transaction(() async {
      await (_database.delete(_database.attachmentsTable)..where((tbl) {
            return tbl.messageId.isInQuery(
              _database.selectOnly(_database.messagesTable)
                ..addColumns([_database.messagesTable.id])
                ..where(
                  _database.messagesTable.conversationId.equals(conversationId),
                ),
            );
          }))
          .go();
      await (_database.delete(
        _database.messagesTable,
      )..where((tbl) => tbl.conversationId.equals(conversationId))).go();
      await (_database.delete(
        _database.conversationMembersTable,
      )..where((tbl) => tbl.conversationId.equals(conversationId))).go();
      await (_database.delete(
        _database.conversationsTable,
      )..where((tbl) => tbl.id.equals(conversationId))).go();
    });
  }

  Future<void> updateConversationTitle({
    required String conversationId,
    required String title,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(
      _database.conversationsTable,
    )..where((tbl) => tbl.id.equals(conversationId))).write(
      ConversationsTableCompanion(
        title: drift.Value(title),
        updatedAt: drift.Value(now),
      ),
    );
  }

  Future<void> syncDirectConversationTitle({
    required String peerId,
    required String displayName,
  }) async {
    final conversation = await findDirectConversationByPeerId(peerId);
    if (conversation != null && conversation.title != displayName) {
      await updateConversationTitle(
        conversationId: conversation.id,
        title: displayName,
      );
    }
  }

  Future<void> updateConversationPreview({
    required String conversationId,
    required String preview,
    required int messageTimestamp,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final encryptedPreview =
        await _dataProtectionService.encryptNullable(preview) ?? preview;
    await (_database.update(
      _database.conversationsTable,
    )..where((tbl) => tbl.id.equals(conversationId))).write(
      ConversationsTableCompanion(
        lastMessagePreview: drift.Value(encryptedPreview),
        lastMessageAt: drift.Value(messageTimestamp),
        updatedAt: drift.Value(now),
      ),
    );
  }

  Future<ConversationRow> _decryptConversation(ConversationRow row) async {
    return row.copyWith(
      lastMessagePreview: drift.Value(
        await _dataProtectionService.decryptNullable(row.lastMessagePreview),
      ),
    );
  }

  Future<void> pinMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await (_database.update(
      _database.conversationsTable,
    )..where((tbl) => tbl.id.equals(conversationId))).write(
      ConversationsTableCompanion(pinnedMessageId: drift.Value(messageId)),
    );
  }

  Future<void> clearPinnedMessage(String conversationId) async {
    await (_database.update(
      _database.conversationsTable,
    )..where((tbl) => tbl.id.equals(conversationId))).write(
      const ConversationsTableCompanion(pinnedMessageId: drift.Value(null)),
    );
  }

  Future<void> incrementUnreadCount(String conversationId) async {
    final conversation = await getConversationById(conversationId);
    if (conversation == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(
      _database.conversationsTable,
    )..where((tbl) => tbl.id.equals(conversationId))).write(
      ConversationsTableCompanion(
        unreadCount: drift.Value(conversation.unreadCount + 1),
        updatedAt: drift.Value(now),
      ),
    );
  }

  Future<void> markConversationRead(String conversationId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(
      _database.conversationsTable,
    )..where((tbl) => tbl.id.equals(conversationId))).write(
      ConversationsTableCompanion(
        unreadCount: const drift.Value(0),
        updatedAt: drift.Value(now),
      ),
    );
  }

  Future<PeerRow?> getDirectPeerForConversation({
    required String conversationId,
    required String localPeerId,
  }) async {
    final member =
        await (_database.select(_database.conversationMembersTable)..where(
              (tbl) =>
                  tbl.conversationId.equals(conversationId) &
                  tbl.peerId.isNotValue(localPeerId),
            ))
            .getSingleOrNull();

    if (member == null) return null;

    return (_database.select(
      _database.peersTable,
    )..where((tbl) => tbl.peerId.equals(member.peerId))).getSingleOrNull();
  }

  Future<List<PeerRow>> getConversationPeers(String conversationId) async {
    final members = await getConversationMembers(conversationId);
    final peerIds = members.map((member) => member.peerId).toList();
    if (peerIds.isEmpty) return const [];

    return (_database.select(
      _database.peersTable,
    )..where((tbl) => tbl.peerId.isIn(peerIds))).get();
  }

  Future<void> _upsertConversationMember({
    required String conversationId,
    required String peerId,
    required String role,
    required int joinedAt,
  }) async {
    final existing = await getMembership(
      conversationId: conversationId,
      peerId: peerId,
    );

    if (existing == null) {
      await _database
          .into(_database.conversationMembersTable)
          .insert(
            ConversationMembersTableCompanion.insert(
              id: _uuid.v4(),
              conversationId: conversationId,
              peerId: peerId,
              role: role,
              joinedAt: joinedAt,
            ),
          );
      return;
    }

    await (_database.update(
      _database.conversationMembersTable,
    )..where((tbl) => tbl.id.equals(existing.id))).write(
      ConversationMembersTableCompanion(
        role: drift.Value(role),
        joinedAt: drift.Value(joinedAt),
      ),
    );
  }
}

class GroupConversationMemberSeed {
  final String peerId;
  final String role;
  final int? joinedAt;

  const GroupConversationMemberSeed({
    required this.peerId,
    required this.role,
    this.joinedAt,
  });
}
