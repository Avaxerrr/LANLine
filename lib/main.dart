import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'app/app_shell.dart';
import 'core/db/app_database.dart';
import 'core/identity/identity_service.dart';
import 'core/providers/app_metadata_provider.dart';
import 'core/providers/app_theme_provider.dart';
import 'core/providers/v2_database_provider.dart';
import 'core/repositories/identity_repository.dart';
import 'core/security/device_signature_service.dart';
import 'core/security/shared_preferences_secret_store.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/username_provider.dart';
import 'core/services/notification_service.dart';

class WindowSaver with WindowListener {
  final SharedPreferences prefs;
  WindowSaver(this.prefs) {
    windowManager.addListener(this);
  }

  @override
  void onWindowMoved() async {
    final pos = await windowManager.getPosition();
    prefs.setDouble('window_x', pos.dx);
    prefs.setDouble('window_y', pos.dy);
  }

  @override
  void onWindowResized() async {
    final size = await windowManager.getSize();
    prefs.setDouble('window_w', size.width);
    prefs.setDouble('window_h', size.height);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await NotificationService().initialize();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    final x = prefs.getDouble('window_x');
    final y = prefs.getDouble('window_y');
    final w = prefs.getDouble('window_w') ?? 450;
    final h = prefs.getDouble('window_h') ?? 850;

    WindowOptions windowOptions = WindowOptions(
      size: Size(w, h),
      minimumSize: const Size(350, 600),
      center: (x == null || y == null),
      backgroundColor: Colors.transparent,
      title: 'LANLine',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();

      if (x != null && y != null) {
        await windowManager.setPosition(Offset(x, y));
      }
    });

    WindowSaver(prefs);
  }

  final packageInfo = await PackageInfo.fromPlatform();
  final database = AppDatabase();
  await IdentityService(
    repository: IdentityRepository(database),
    prefs: prefs,
    signatureService: DeviceSignatureService(
      SharedPreferencesSecretStore(prefs),
    ),
  ).bootstrap();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(database),
        appVersionProvider.overrideWithValue(packageInfo.version),
      ],
      child: const LANLineApp(),
    ),
  );
}

class LANLineApp extends ConsumerWidget {
  const LANLineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(appThemeDataProvider);

    return MaterialApp(
      title: 'LANLine',
      theme: AppTheme.lightTheme,
      darkTheme: activeTheme,
      themeMode: ThemeMode.dark,
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
