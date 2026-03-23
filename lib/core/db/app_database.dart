import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/attachments_table.dart';
import 'tables/contact_requests_table.dart';
import 'tables/conversation_members_table.dart';
import 'tables/conversations_table.dart';
import 'tables/local_identity_table.dart';
import 'tables/messages_table.dart';
import 'tables/outbox_table.dart';
import 'tables/peers_table.dart';
import 'tables/presence_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    LocalIdentityTable,
    PeersTable,
    PresenceTable,
    ContactRequestsTable,
    ConversationsTable,
    ConversationMembersTable,
    MessagesTable,
    AttachmentsTable,
    OutboxTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(
          conversationsTable,
          conversationsTable.pinnedMessageId,
        );
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(documentsDir.path, 'lanline_v2.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
