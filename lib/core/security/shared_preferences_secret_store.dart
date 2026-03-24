import 'package:shared_preferences/shared_preferences.dart';

import 'secret_store.dart';

class SharedPreferencesSecretStore implements SecretStore {
  static const _prefix = 'lanline_secret_';

  final SharedPreferences _prefs;

  SharedPreferencesSecretStore(this._prefs);

  String _storageKey(String key) => '$_prefix$key';

  @override
  Future<String?> read(String key) async {
    return _prefs.getString(_storageKey(key));
  }

  @override
  Future<void> write(String key, String value) async {
    await _prefs.setString(_storageKey(key), value);
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(_storageKey(key));
  }
}
