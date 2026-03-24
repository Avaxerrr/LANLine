import 'package:drift/drift.dart' as drift;

import '../db/app_database.dart';

class IdentityRepository {
  final AppDatabase _database;

  IdentityRepository(this._database);

  Future<LocalIdentityRow?> getLocalIdentity() {
    return (_database.select(
      _database.localIdentityTable,
    )..limit(1)).getSingleOrNull();
  }

  Stream<LocalIdentityRow?> watchLocalIdentity() {
    return (_database.select(
      _database.localIdentityTable,
    )..limit(1)).watchSingleOrNull();
  }

  Future<LocalIdentityRow> createIdentity({
    required String id,
    required String peerId,
    required String displayName,
    String? deviceLabel,
    required String fingerprint,
    String? signingPublicKey,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database
        .into(_database.localIdentityTable)
        .insert(
          LocalIdentityTableCompanion.insert(
            id: id,
            peerId: peerId,
            displayName: displayName,
            deviceLabel: drift.Value(deviceLabel),
            fingerprint: fingerprint,
            signingPublicKey: drift.Value(signingPublicKey),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (await getLocalIdentity())!;
  }

  Future<LocalIdentityRow> updateIdentity({
    required String id,
    required String displayName,
    String? deviceLabel,
    String? signingPublicKey,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_database.update(
      _database.localIdentityTable,
    )..where((tbl) => tbl.id.equals(id))).write(
      LocalIdentityTableCompanion(
        displayName: drift.Value(displayName),
        deviceLabel: drift.Value(deviceLabel),
        signingPublicKey: drift.Value(signingPublicKey),
        updatedAt: drift.Value(now),
      ),
    );
    return (await getLocalIdentity())!;
  }
}
