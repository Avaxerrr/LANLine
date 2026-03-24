import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import 'attachments_repository.dart';
import 'conversations_repository.dart';
import '../security/local_data_protection_service.dart';

class MessagesRepository {
  final AppDatabase _database;
  final ConversationsRepository _conversationsRepository;
  final AttachmentsRepository _attachmentsRepository;
  final LocalDataProtectionService _dataProtectionService;
  final int Function() _readRetentionLimit;
  final Uuid _uuid;

  MessagesRepository(
    this._database, {
    required ConversationsRepository conversationsRepository,
    required AttachmentsRepository attachmentsRepository,
    required LocalDataProtectionService dataProtectionService,
    required int Function() readRetentionLimit,
    Uuid? uuid,
  }) : _conversationsRepository = conversationsRepository,
       _attachmentsRepository = attachmentsRepository,
       _dataProtectionService = dataProtectionService,
       _readRetentionLimit = readRetentionLimit,
       _uuid = uuid ?? const Uuid();

  Stream<List<MessageRow>> watchMessages(String conversationId) {
    return (_database.select(_database.messagesTable)
          ..where((tbl) => tbl.conversationId.equals(conversationId))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.createdLocallyAt)]))
        .watch()
        .asyncMap((rows) async => Future.wait(rows.map(_decryptMessage)));
  }

  Stream<List<MessageRow>> watchMessagesPage(
    String conversationId, {
    required int limit,
  }) {
    return (_database.select(_database.messagesTable)
          ..where((tbl) => tbl.conversationId.equals(conversationId))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdLocallyAt)])
          ..limit(limit))
        .watch()
        .asyncMap((rows) async {
          final ordered = rows.reversed.toList(growable: false);
          return Future.wait(ordered.map(_decryptMessage));
        });
  }

  Future<MessageRow?> getMessageByClientGeneratedId(String clientGeneratedId) {
    return (_database.select(_database.messagesTable)
          ..where((tbl) => tbl.clientGeneratedId.equals(clientGeneratedId)))
        .getSingleOrNull()
        .then((row) => row == null ? null : _decryptMessage(row));
  }

  Future<MessageRow?> getMessageById(String messageId) {
    return (_database.select(_database.messagesTable)
          ..where((tbl) => tbl.id.equals(messageId)))
        .getSingleOrNull()
        .then((row) => row == null ? null : _decryptMessage(row));
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
    final encryptedText = await _dataProtectionService.encryptNullable(
      textBody,
    );
    final encryptedMetadata = await _dataProtectionService.encryptNullable(
      metadataJson,
    );

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
              textBody: drift.Value(encryptedText),
              status: status,
              replyToMessageId: drift.Value(replyToMessageId),
              metadataJson: drift.Value(encryptedMetadata),
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

      final retentionLimit = _readRetentionLimit();
      if (retentionLimit > 0) {
        await _trimConversationToRetention(
          conversationId: conversationId,
          keepLatest: retentionLimit,
        );
      }
    });

    return (_database.select(_database.messagesTable)
          ..where((tbl) => tbl.id.equals(messageId)))
        .getSingle()
        .then((row) => _decryptMessage(row));
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

  Future<void> deleteMessage(String messageId) async {
    final message = await getMessageById(messageId);
    if (message == null) return;
    final conversation = await _conversationsRepository.getConversationById(
      message.conversationId,
    );

    await _database.transaction(() async {
      if (conversation?.pinnedMessageId == messageId) {
        await _conversationsRepository.clearPinnedMessage(
          message.conversationId,
        );
      }
      await _attachmentsRepository.deleteAttachmentsForMessage(messageId);
      await (_database.delete(
        _database.messagesTable,
      )..where((tbl) => tbl.id.equals(messageId))).go();
      await _refreshConversationPreview(message.conversationId);
    });
  }

  Future<void> _refreshConversationPreview(String conversationId) async {
    final latestMessage =
        await (_database.select(_database.messagesTable)
              ..where((tbl) => tbl.conversationId.equals(conversationId))
              ..orderBy([
                (tbl) => drift.OrderingTerm.desc(tbl.createdLocallyAt),
              ])
              ..limit(1))
            .getSingleOrNull();

    final now = DateTime.now().millisecondsSinceEpoch;

    if (latestMessage == null) {
      await (_database.update(
        _database.conversationsTable,
      )..where((tbl) => tbl.id.equals(conversationId))).write(
        ConversationsTableCompanion(
          lastMessagePreview: const drift.Value(null),
          lastMessageAt: const drift.Value(null),
          updatedAt: drift.Value(now),
        ),
      );
      return;
    }

    final latestPreview =
        await _dataProtectionService.decryptNullable(latestMessage.textBody) ??
        latestMessage.type;
    await _conversationsRepository.updateConversationPreview(
      conversationId: conversationId,
      preview: latestPreview,
      messageTimestamp: latestMessage.sentAt ?? latestMessage.createdLocallyAt,
    );
  }

  Future<void> _trimConversationToRetention({
    required String conversationId,
    required int keepLatest,
  }) async {
    final overflowMessages =
        await (_database.select(_database.messagesTable)
              ..where((tbl) => tbl.conversationId.equals(conversationId))
              ..orderBy([
                (tbl) => drift.OrderingTerm.desc(tbl.createdLocallyAt),
              ])
              ..limit(999999, offset: keepLatest))
            .get();

    if (overflowMessages.isEmpty) return;

    final conversation = await _conversationsRepository.getConversationById(
      conversationId,
    );
    for (final message in overflowMessages) {
      if (conversation?.pinnedMessageId == message.id) {
        await _conversationsRepository.clearPinnedMessage(conversationId);
      }
      await _attachmentsRepository.deleteAttachmentsForMessage(message.id);
      await (_database.delete(
        _database.messagesTable,
      )..where((tbl) => tbl.id.equals(message.id))).go();
    }
  }

  Future<MessageRow> _decryptMessage(MessageRow row) async {
    return row.copyWith(
      textBody: drift.Value(
        await _dataProtectionService.decryptNullable(row.textBody),
      ),
      metadataJson: drift.Value(
        await _dataProtectionService.decryptNullable(row.metadataJson),
      ),
    );
  }
}
