import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/username_provider.dart';
import 'core/services/notification_service.dart';
import 'features/room/presentation/room_list_screen.dart';
import 'features/connection/presentation/client_scanner_screen.dart';
import 'features/downloads/presentation/download_history_screen.dart';

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

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const LANLineApp(),
    ),
  );
}

class LANLineApp extends StatelessWidget {
  const LANLineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LANLine',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Enforcing dark mode for a sleeker look
      home: const MainMenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainMenuScreen extends ConsumerStatefulWidget {
  const MainMenuScreen({super.key});

  @override
  ConsumerState<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends ConsumerState<MainMenuScreen> {
  final TextEditingController _nameController = TextEditingController();

  void _saveName() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      ref.read(usernameProvider.notifier).setName(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentName = ref.watch(usernameProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Row(
          children: [
            Text(
              'LANLine ',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2),
            ),
            Text('v0.3.0', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: currentName.isEmpty
          ? Center(child: _buildNamePrompt())
          : Align(
              alignment: Alignment.topCenter,
              child: _buildActionMenu(currentName),
            ),
    );
  }

  Widget _buildNamePrompt() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_pin,
              size: 80,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Who are you?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a display name for the local network.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'e.g. Maverick',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: const BorderSide(
                  color: Colors.blueAccent,
                  width: 2,
                ),
              ),
            ),
            onSubmitted: (_) => _saveName(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _saveName,
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu(String name) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blueAccent,
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome, $name!',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 48),
          _buildMenuButton(
            icon: Icons.hub_rounded,
            label: 'My Rooms',
            color: Colors.blueAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RoomListScreen()),
            ),
          ),
          const SizedBox(height: 20),
          _buildMenuButton(
            icon: Icons.login_rounded,
            label: 'Join Room',
            color: Colors.tealAccent.shade400,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientScannerScreen()),
            ),
          ),
          const SizedBox(height: 20),
          _buildMenuButton(
            icon: Icons.download_rounded,
            label: 'Downloads',
            color: Colors.deepPurpleAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DownloadHistoryScreen()),
            ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
            label: const Text(
              'Change Name',
              style: TextStyle(color: Colors.grey),
            ),
            onPressed: () => ref.read(usernameProvider.notifier).setName(''),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 280,
      height: 65,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }
}
