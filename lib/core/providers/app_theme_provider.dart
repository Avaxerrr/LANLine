import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'username_provider.dart';

class AppThemePresetNotifier extends Notifier<AppThemePreset> {
  static const _key = 'lanline_theme_preset';

  @override
  AppThemePreset build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppThemePresetX.fromStorage(prefs.getString(_key));
  }

  Future<void> setPreset(AppThemePreset preset) async {
    state = preset;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, preset.storageValue);
  }
}

final appThemePresetProvider =
    NotifierProvider<AppThemePresetNotifier, AppThemePreset>(() {
      return AppThemePresetNotifier();
    });

final appThemeDataProvider = Provider<ThemeData>((ref) {
  final preset = ref.watch(appThemePresetProvider);
  return AppTheme.darkTheme(preset);
});
