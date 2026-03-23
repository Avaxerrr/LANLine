import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/repositories/attachments_repository.dart';

void main() {
  late AppDatabase database;
  late AttachmentsRepository attachmentsRepository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    attachmentsRepository = AttachmentsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('insertAttachment persists attachment rows and fetches them by message', () async {
    final inserted = await attachmentsRepository.insertAttachment(
      messageId: 'message-1',
      kind: 'file',
      fileName: 'report.pdf',
      fileSize: 1024,
      mimeType: 'application/pdf',
      localPath: '/tmp/report.pdf',
      transferState: 'pending',
      checksum: 'abc123',
    );

    final byMessage = await attachmentsRepository.getAttachmentsByMessageId(
      'message-1',
    );
    final watched = await attachmentsRepository
        .watchAttachmentsForMessage('message-1')
        .first;

    expect(byMessage, hasLength(1));
    expect(watched, hasLength(1));
    expect(byMessage.single.id, inserted.id);
    expect(byMessage.single.messageId, 'message-1');
    expect(byMessage.single.fileName, 'report.pdf');
    expect(byMessage.single.transferState, 'pending');
    expect(byMessage.single.localPath, '/tmp/report.pdf');
    expect(byMessage.single.checksum, 'abc123');
  });

  test(
    'updateAttachmentTransferMetadata updates transfer state and file metadata',
    () async {
      final inserted = await attachmentsRepository.insertAttachment(
        messageId: 'message-2',
        kind: 'image',
        fileName: 'photo.jpg',
        fileSize: 2048,
        transferState: 'pending',
      );

      await attachmentsRepository.updateAttachmentTransferMetadata(
        attachmentId: inserted.id,
        transferState: 'complete',
        localPath: '/downloads/LANLine/photo.jpg',
        checksum: 'checksum-456',
        width: 1920,
        height: 1080,
        durationMs: 0,
      );

      final updated = await attachmentsRepository.getAttachmentById(inserted.id);

      expect(updated, isNotNull);
      expect(updated!.transferState, 'complete');
      expect(updated.localPath, '/downloads/LANLine/photo.jpg');
      expect(updated.checksum, 'checksum-456');
      expect(updated.width, 1920);
      expect(updated.height, 1080);
      expect(updated.durationMs, 0);
      expect(updated.updatedAt, isNot(inserted.updatedAt));
    },
  );
}
