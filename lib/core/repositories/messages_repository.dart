import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import 'conversations_repository.dart';

class MessagesRepository {
  final AppDatabase _database;
  final ConversationsRepository _conversationsRepository;
  final Uuid _uuid;

  MessagesRepository(
    this._database, {
    required ConversationsRepository conversationsRepository,
    Uuid? uuid,
  }) : _conversationsRepository = conversationsRepository,
       _uuid = uuid ?? const Uuid();

  Stream<List<MessageRow>> watchMessages(String conversationId) {
    return (_database.select(_database.messagesTable)
          ..where((tbl) => tbl.conversationId.equals(conversationId))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.createdLocallyAt)]))
        .watch();
  }

  Future<MessageRow> insertMessage({
    required String conversationId,
    required String senderPeerId,
    required String type,
    String? textBody,
    String status = 'pending',
    String? replyToMessageId,
    String? metadataJson,
    int? sentAt,
    int? receivedAt,
    int? readAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final clientGeneratedId = _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.messagesTable)
          .insert(
            MessagesTableCompanion.insert(
              id: id,
              conversationId: conversationId,
              senderPeerId: senderPeerId,
              clientGeneratedId: clientGeneratedId,
              type: type,
              textBody: drift.Value(textBody),
              status: status,
              replyToMessageId: drift.Value(replyToMessageId),
              metadataJson: drift.Value(metadataJson),
              sentAt: drift.Value(sentAt),
              receivedAt: drift.Value(receivedAt),
              readAt: drift.Value(readAt),
              createdLocallyAt: now,
              updatedAt: now,
            ),
          );

      await _conversationsRepository.updateConversationPreview(
        conversationId: conversationId,
        preview: textBody ?? type,
        messageTimestamp: sentAt ?? now,
      );
    });

    return (_database.select(
      _database.messagesTable,
    )..where((tbl) => tbl.id.equals(id))).getSingle();
  }

  Future<void> updateMessageStatus(String messageId, String status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(
      _database.messagesTable,
    )..where((tbl) => tbl.id.equals(messageId))).write(
      MessagesTableCompanion(
        status: drift.Value(status),
        updatedAt: drift.Value(now),
      ),
    );
  }
}
