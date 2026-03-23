import 'package:drift/drift.dart';

@DataClassName('AttachmentRow')
class AttachmentsTable extends Table {
  TextColumn get id => text()();
  TextColumn get messageId => text().named('message_id')();
  TextColumn get kind => text()();
  TextColumn get fileName => text().named('file_name')();
  TextColumn get mimeType => text().named('mime_type').nullable()();
  IntColumn get fileSize => integer().named('file_size')();
  TextColumn get localPath => text().named('local_path').nullable()();
  TextColumn get transferState => text().named('transfer_state')();
  TextColumn get checksum => text().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationMs => integer().named('duration_ms').nullable()();
  IntColumn get createdAt => integer().named('created_at')();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
