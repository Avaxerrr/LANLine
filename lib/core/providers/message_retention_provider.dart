import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'username_provider.dart';

const retentionUnlimited = 0;
const retentionChoices = <int>[retentionUnlimited, 250, 1000, 5000];

final messageRetentionLimitProvider =
    NotifierProvider<MessageRetentionLimitNotifier, int>(
      MessageRetentionLimitNotifier.new,
    );

class MessageRetentionLimitNotifier extends Notifier<int> {
  static const _key = 'lanline_message_retention_limit';

  @override
  int build() {
    return ref.read(sharedPreferencesProvider).getInt(_key) ?? retentionUnlimited;
  }

  Future<void> setLimit(int value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).setInt(_key, value);
  }
}
