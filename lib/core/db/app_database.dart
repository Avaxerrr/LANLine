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
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createPerformanceIndexes();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(
          conversationsTable,
          conversationsTable.pinnedMessageId,
        );
      }
      if (from < 3) {
        await _createPerformanceIndexes();
      }
      if (from < 4) {
        await m.addColumn(
          localIdentityTable,
          localIdentityTable.signingPublicKey,
        );
        await m.addColumn(peersTable, peersTable.signingPublicKey);
      }
      if (from < 5) {
        await _addColumnIfNotExists(
          m,
          peersTable,
          peersTable.useTunnel,
          'use_tunnel',
          'peers_table',
        );
        await _addColumnIfNotExists(
          m,
          peersTable,
          peersTable.tunnelHost,
          'tunnel_host',
          'peers_table',
        );
        await _addColumnIfNotExists(
          m,
          peersTable,
          peersTable.tunnelPort,
          'tunnel_port',
          'peers_table',
        );
      }
    },
  );

  Future<void> _addColumnIfNotExists(
    Migrator m,
    TableInfo table,
    GeneratedColumn column,
    String columnName,
    String tableName,
  ) async {
    final result = await customSelect(
      'PRAGMA table_info($tableName)',
    ).get();
    final exists = result.any((row) => row.data['name'] == columnName);
    if (!exists) {
      await m.addColumn(table, column);
    }
  }

  Future<void> _createPerformanceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_presence_peer_reachable '
      'ON presence_table (peer_id, is_reachable, updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_peers_relationship_display '
      'ON peers_table (relationship_state, display_name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_requests_peer_status_updated '
      'ON contact_requests_table (peer_id, status, updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_conversations_recent '
      'ON conversations_table (last_message_at, updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_conversation_members_conversation '
      'ON conversation_members_table (conversation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_messages_conversation_created '
      'ON messages_table (conversation_id, created_locally_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_attachments_message '
      'ON attachments_table (message_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_outbox_peer_created '
      'ON outbox_table (peer_id, created_at)',
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(documentsDir.path, 'lanline_v2.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
