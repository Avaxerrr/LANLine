import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

class ConversationsRepository {
  final AppDatabase _database;
  final Uuid _uuid;

  ConversationsRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  Stream<List<ConversationRow>> watchConversationList() {
    return (_database.select(_database.conversationsTable)..orderBy([
          (tbl) => drift.OrderingTerm.desc(tbl.lastMessageAt),
          (tbl) => drift.OrderingTerm.desc(tbl.updatedAt),
        ]))
        .watch();
  }

  Future<ConversationRow?> getConversationById(String conversationId) {
    return (_database.select(
      _database.conversationsTable,
    )..where((tbl) => tbl.id.equals(conversationId))).getSingleOrNull();
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
      if (title != null &&
          title.isNotEmpty &&
          existing.title != title) {
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

    return (_database.select(
      _database.conversationsTable,
    )..where((tbl) => tbl.id.equals(conversationId))).getSingle();
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

  Future<void> updateConversationPreview({
    required String conversationId,
    required String preview,
    required int messageTimestamp,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(
      _database.conversationsTable,
    )..where((tbl) => tbl.id.equals(conversationId))).write(
      ConversationsTableCompanion(
        lastMessagePreview: drift.Value(preview),
        lastMessageAt: drift.Value(messageTimestamp),
        updatedAt: drift.Value(now),
      ),
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
    final member = await (_database.select(_database.conversationMembersTable)
          ..where(
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
}
