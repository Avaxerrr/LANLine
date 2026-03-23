import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

class AttachmentsRepository {
  final AppDatabase _database;
  final Uuid _uuid;

  AttachmentsRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  Stream<List<AttachmentRow>> watchAttachmentsForMessage(String messageId) {
    return (_database.select(_database.attachmentsTable)
          ..where((tbl) => tbl.messageId.equals(messageId))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.createdAt)]))
        .watch();
  }

  Future<List<AttachmentRow>> getAttachmentsByMessageId(String messageId) {
    return (_database.select(_database.attachmentsTable)
          ..where((tbl) => tbl.messageId.equals(messageId))
          ..orderBy([(tbl) => drift.OrderingTerm.asc(tbl.createdAt)]))
        .get();
  }

  Future<AttachmentRow?> getAttachmentById(String attachmentId) {
    return (_database.select(
      _database.attachmentsTable,
    )..where((tbl) => tbl.id.equals(attachmentId))).getSingleOrNull();
  }

  Future<AttachmentRow> insertAttachment({
    String? id,
    required String messageId,
    required String kind,
    required String fileName,
    required int fileSize,
    String? mimeType,
    String? localPath,
    required String transferState,
    String? checksum,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final attachmentId = id ?? _uuid.v4();

    await _database
        .into(_database.attachmentsTable)
        .insert(
          AttachmentsTableCompanion.insert(
            id: attachmentId,
            messageId: messageId,
            kind: kind,
            fileName: fileName,
            fileSize: fileSize,
            transferState: transferState,
            mimeType: drift.Value(mimeType),
            localPath: drift.Value(localPath),
            checksum: drift.Value(checksum),
            width: drift.Value(width),
            height: drift.Value(height),
            durationMs: drift.Value(durationMs),
            createdAt: now,
            updatedAt: now,
          ),
        );

    return (_database.select(
      _database.attachmentsTable,
    )..where((tbl) => tbl.id.equals(attachmentId))).getSingle();
  }

  Future<void> updateAttachmentTransferMetadata({
    required String attachmentId,
    String? transferState,
    String? localPath,
    String? checksum,
    int? width,
    int? height,
    int? durationMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(
      _database.attachmentsTable,
    )..where((tbl) => tbl.id.equals(attachmentId))).write(
      AttachmentsTableCompanion(
        transferState: transferState == null
            ? const drift.Value.absent()
            : drift.Value(transferState),
        localPath: localPath == null
            ? const drift.Value.absent()
            : drift.Value(localPath),
        checksum: checksum == null
            ? const drift.Value.absent()
            : drift.Value(checksum),
        width: width == null ? const drift.Value.absent() : drift.Value(width),
        height: height == null ? const drift.Value.absent() : drift.Value(height),
        durationMs: durationMs == null
            ? const drift.Value.absent()
            : drift.Value(durationMs),
        updatedAt: drift.Value(now),
      ),
    );
  }
}
