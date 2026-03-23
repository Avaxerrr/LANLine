import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/identity/identity_service.dart';
import 'package:lanline/core/repositories/identity_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase database;
  late IdentityRepository repository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    repository = IdentityRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('bootstrap creates local identity on first run', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final service = IdentityService(repository: repository, prefs: prefs);
    final identity = await service.bootstrap();

    expect(identity.id, 'local_identity');
    expect(identity.peerId, isNotEmpty);
    expect(identity.fingerprint, matches(RegExp(r'^[A-F0-9]{4}-[A-F0-9]{2}$')));
    expect(identity.displayName, IdentityService.defaultDisplayName);
  });

  test('bootstrap seeds identity from legacy username', () async {
    SharedPreferences.setMockInitialValues({
      IdentityService.legacyUsernameKey: 'LegacyName',
    });
    final prefs = await SharedPreferences.getInstance();

    final service = IdentityService(repository: repository, prefs: prefs);
    final identity = await service.bootstrap();

    expect(identity.displayName, 'LegacyName');
  });

  test('bootstrap is stable across repeated runs', () async {
    SharedPreferences.setMockInitialValues({
      IdentityService.legacyUsernameKey: 'StableName',
    });
    final prefs = await SharedPreferences.getInstance();
    final service = IdentityService(repository: repository, prefs: prefs);

    final first = await service.bootstrap();
    final second = await service.bootstrap();

    expect(second.id, first.id);
    expect(second.peerId, first.peerId);
    expect(second.fingerprint, first.fingerprint);
  });

  test(
    'bootstrap syncs display name from legacy username on later launch',
    () async {
      SharedPreferences.setMockInitialValues({
        IdentityService.legacyUsernameKey: 'FirstName',
      });
      var prefs = await SharedPreferences.getInstance();
      var service = IdentityService(repository: repository, prefs: prefs);

      final first = await service.bootstrap();
      expect(first.displayName, 'FirstName');

      SharedPreferences.setMockInitialValues({
        IdentityService.legacyUsernameKey: 'UpdatedName',
      });
      prefs = await SharedPreferences.getInstance();
      service = IdentityService(repository: repository, prefs: prefs);

      final second = await service.bootstrap();
      expect(second.peerId, first.peerId);
      expect(second.displayName, 'UpdatedName');
    },
  );
}
