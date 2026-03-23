import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/v2_presence_discovery_provider.dart';
import '../core/providers/v2_request_protocol_provider.dart';
import '../features/chats/presentation/chats_screen.dart';
import '../features/people/presentation/people_screen.dart';
import '../features/requests/presentation/requests_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  void _goToPeople() {
    setState(() => _selectedIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(v2PresenceDiscoveryControllerProvider);
    ref.watch(v2RequestProtocolControllerProvider);

    final screens = <Widget>[
      ChatsScreen(onGoToPeople: _goToPeople),
      const PeopleScreen(),
      const RequestsScreen(),
      const SettingsScreen(),
    ];

    final titles = ['Chats', 'People', 'Requests', 'Settings'];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          titles[_selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        backgroundColor: const Color(0xFF181818),
        indicatorColor: Colors.blueAccent.withValues(alpha: 0.2),
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
