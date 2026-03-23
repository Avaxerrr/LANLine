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
  }) async {
    final existing = await findDirectConversationByPeerId(peerId);
    if (existing != null) return existing;

    final now = DateTime.now().millisecondsSinceEpoch;
    final conversationId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.conversationsTable)
          .insert(
            ConversationsTableCompanion.insert(
              id: conversationId,
              type: 'direct',
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
}
