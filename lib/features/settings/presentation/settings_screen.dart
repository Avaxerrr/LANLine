import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_metadata_provider.dart';
import '../../../core/providers/username_provider.dart';
import '../../../core/providers/v2_identity_provider.dart';
import '../../connection/presentation/client_scanner_screen.dart';
import '../../downloads/presentation/download_history_screen.dart';
import '../../room/presentation/room_list_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _deviceLabelController = TextEditingController();
  bool _initializedControllers = false;

  @override
  void dispose() {
    _nameController.dispose();
    _deviceLabelController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final identity = await ref.read(localIdentityProvider.future);
    if (identity == null) return;

    final newName = _nameController.text.trim();
    final newDeviceLabel = _deviceLabelController.text.trim();
    if (newName.isEmpty) return;

    ref.read(usernameProvider.notifier).setName(newName);
    await ref
        .read(identityServiceProvider)
        .updateProfile(
          displayName: newName,
          deviceLabel: newDeviceLabel.isEmpty ? null : newDeviceLabel,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(localIdentityProvider);
    final version = ref.watch(appVersionProvider);

    return identityAsync.when(
      data: (identity) {
        if (identity != null && !_initializedControllers) {
          _nameController.text = identity.displayName;
          _deviceLabelController.text = identity.deviceLabel ?? '';
          _initializedControllers = true;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1B),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _deviceLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Device label',
                      prefixIcon: Icon(Icons.devices_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    label: 'Fingerprint',
                    value: identity?.fingerprint ?? 'Unavailable',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'App version', value: version),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Profile'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Legacy LAN Rooms',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Temporary access to the old room-based flow while V2 is being migrated.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 14),
            _LegacyActionCard(
              icon: Icons.hub_outlined,
              title: 'My Rooms',
              subtitle: 'Open the old room host list',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoomListScreen()),
              ),
            ),
            _LegacyActionCard(
              icon: Icons.login_rounded,
              title: 'Join Room',
              subtitle: 'Use the old scanner and manual room join flow',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientScannerScreen()),
              ),
            ),
            _LegacyActionCard(
              icon: Icons.download_rounded,
              title: 'Downloads',
              subtitle: 'Open the existing download history screen',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadHistoryScreen(),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load settings: $error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _LegacyActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LegacyActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1B1B1B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.withValues(alpha: 0.16),
          child: Icon(icon, color: Colors.white70),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
