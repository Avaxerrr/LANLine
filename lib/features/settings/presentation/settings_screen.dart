import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/providers/app_metadata_provider.dart';
import '../../../core/providers/username_provider.dart';
import '../../../core/providers/v2_identity_provider.dart';
import '../../downloads/presentation/download_history_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _deviceLabelController = TextEditingController();
  bool _initializedControllers = false;
  bool _showQr = false;

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

        final qrPayload = identity == null
            ? null
            : jsonEncode({
                'protocol': 'lanline_v2_identity',
                'peerId': identity.peerId,
                'displayName': identity.displayName,
                'deviceLabel': identity.deviceLabel,
                'fingerprint': identity.fingerprint,
              });

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _SurfaceCard(
              title: 'Profile',
              subtitle: 'Update how other devices identify you.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 18),
                  _InfoRow(
                    label: 'Fingerprint',
                    value: identity?.fingerprint ?? 'Unavailable',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'App version', value: version),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save Profile'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SurfaceCard(
              title: 'Share Profile',
              subtitle:
                  'Reveal your QR only when you want to pair or share identity.',
              trailing: TextButton.icon(
                onPressed: identity == null
                    ? null
                    : () => setState(() => _showQr = !_showQr),
                icon: Icon(_showQr ? Icons.visibility_off : Icons.qr_code_2),
                label: Text(_showQr ? 'Hide QR' : 'Show QR'),
              ),
              child: AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: qrPayload == null
                      ? const _MutedMessage(
                          text: 'Identity is unavailable right now.',
                        )
                      : Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: QrImageView(
                                data: qrPayload,
                                version: QrVersions.auto,
                                size: 210,
                                backgroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              identity?.displayName ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              identity?.fingerprint ?? '',
                              style: const TextStyle(color: Colors.white60),
                            ),
                          ],
                        ),
                ),
                crossFadeState: _showQr
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
            ),
            const SizedBox(height: 18),
            _SurfaceCard(
              title: 'History',
              subtitle: 'Review received files and manage stored downloads.',
              child: _SettingsActionCard(
                icon: Icons.download_rounded,
                title: 'Downloads',
                subtitle: 'Browse files you already received',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DownloadHistoryScreen(),
                  ),
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
            style: const TextStyle(color: Colors.white60),
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _SurfaceCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[trailing!],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MutedMessage extends StatelessWidget {
  final String text;

  const _MutedMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Colors.white60));
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
          child: Text(label, style: const TextStyle(color: Colors.white60)),
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

class _SettingsActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.03),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.withValues(alpha: 0.16),
          child: Icon(icon, color: Colors.white70),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white60)),
        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
