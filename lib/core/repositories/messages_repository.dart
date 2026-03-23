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

  Future<MessageRow?> getMessageByClientGeneratedId(String clientGeneratedId) {
    return (_database.select(
      _database.messagesTable,
    )..where((tbl) => tbl.clientGeneratedId.equals(clientGeneratedId)))
        .getSingleOrNull();
  }

  Future<MessageRow?> getMessageById(String messageId) {
    return (_database.select(
      _database.messagesTable,
    )..where((tbl) => tbl.id.equals(messageId))).getSingleOrNull();
  }

  Future<MessageRow> insertMessage({
    required String conversationId,
    required String senderPeerId,
    required String type,
    String? textBody,
    String status = 'pending',
    String? id,
    String? clientGeneratedId,
    String? replyToMessageId,
    String? metadataJson,
    int? sentAt,
    int? receivedAt,
    int? readAt,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final messageId = id ?? _uuid.v4();
    final messageClientId = clientGeneratedId ?? _uuid.v4();

    await _database.transaction(() async {
      await _database
          .into(_database.messagesTable)
          .insert(
            MessagesTableCompanion.insert(
              id: messageId,
              conversationId: conversationId,
              senderPeerId: senderPeerId,
              clientGeneratedId: messageClientId,
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
    )..where((tbl) => tbl.id.equals(messageId))).getSingle();
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

  Future<void> updateMessageStatusByClientGeneratedId(
    String clientGeneratedId,
    String status,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(
      _database.messagesTable,
    )..where((tbl) => tbl.clientGeneratedId.equals(clientGeneratedId))).write(
      MessagesTableCompanion(
        status: drift.Value(status),
        updatedAt: drift.Value(now),
      ),
    );
  }
}
