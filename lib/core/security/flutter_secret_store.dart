import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secret_store.dart';

class FlutterSecretStore implements SecretStore {
  final FlutterSecureStorage _storage;

  const FlutterSecretStore(this._storage);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
