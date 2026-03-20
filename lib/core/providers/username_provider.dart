import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class UsernameNotifier extends Notifier<String> {
  static const _key = 'lanline_username';

  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_key) ?? '';
  }

  void setName(String name) {
    state = name;
    ref.read(sharedPreferencesProvider).setString(_key, name);
  }
}

final usernameProvider = NotifierProvider<UsernameNotifier, String>(() {
  return UsernameNotifier();
});
