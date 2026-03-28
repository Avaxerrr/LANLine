import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/providers/app_metadata_provider.dart';
import '../../../core/providers/app_theme_provider.dart';
import '../../../core/providers/message_retention_provider.dart';
import '../../../core/providers/username_provider.dart';
import '../../../core/providers/identity_provider.dart';
import '../../../core/providers/presence_discovery_provider.dart';
import '../../../core/theme/app_theme.dart';
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
    await ref
        .read(presenceDiscoveryControllerProvider)
        .refreshIdentity();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(localIdentityProvider);
    final version = ref.watch(appVersionProvider);
    final selectedTheme = ref.watch(appThemePresetProvider);
    final retentionLimit = ref.watch(messageRetentionLimitProvider);

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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 138),
          children: [
            _SurfaceCard(
              title: 'Profile',
              subtitle: 'Update how other devices identify you.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsInputField(
                    label: 'Display name',
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'What other people see',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SettingsInputField(
                    label: 'Device label',
                    child: TextField(
                      controller: _deviceLabelController,
                      decoration: const InputDecoration(
                        hintText: 'Optional device name',
                        prefixIcon: Icon(Icons.devices_outlined),
                      ),
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
              title: 'Appearance',
              subtitle: 'Switch between a few curated dark palettes.',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final preset in AppThemePreset.values)
                    _ThemePresetChip(
                      preset: preset,
                      selected: preset == selectedTheme,
                      onTap: () => ref
                          .read(appThemePresetProvider.notifier)
                          .setPreset(preset),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SurfaceCard(
              title: 'Share Profile',
              subtitle:
                  'Reveal your QR only when you want to pair or share identity.',
              trailing: _QrToggleButton(
                visible: _showQr,
                enabled: identity != null,
                onPressed: identity == null
                    ? null
                    : () => setState(() => _showQr = !_showQr),
              ),
              child: AnimatedCrossFade(
                firstChild: _QrPreviewSummary(identity: identity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: qrPayload == null
                      ? const _MutedMessage(
                          text: 'Identity is unavailable right now.',
                        )
                      : Column(
                          children: [
                            _QrPreviewSummary(identity: identity),
                            const SizedBox(height: 16),
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
              title: 'Storage',
              subtitle:
                  'Control how much message history each conversation keeps locally.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message retention',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final option in retentionChoices)
                        _RetentionChip(
                          value: option,
                          selected: option == retentionLimit,
                          onTap: () => ref
                              .read(messageRetentionLimitProvider.notifier)
                              .setLimit(option),
                        ),
                    ],
                  ),
                ],
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
            style: TextStyle(color: context.appPalette.textMuted),
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
    final palette = context.appPalette;
    final trailingWidget = trailing;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: palette.surfaceGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
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
                      style: TextStyle(color: palette.textMuted, height: 1.35),
                    ),
                  ],
                ),
              ),
              ...?(trailingWidget == null ? null : <Widget>[trailingWidget]),
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
    return Text(text, style: TextStyle(color: context.appPalette.textMuted));
  }
}

class _SettingsInputField extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingsInputField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: palette.inputFill.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.border.withValues(alpha: 0.38)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(color: palette.textMuted)),
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
    final palette = context.appPalette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border.withValues(alpha: 0.25)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: palette.brand.withValues(alpha: 0.14),
          child: Icon(icon, color: palette.brand),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle, style: TextStyle(color: palette.textMuted)),
        trailing: Icon(Icons.chevron_right, color: palette.textMuted),
        onTap: onTap,
      ),
    );
  }
}

class _QrToggleButton extends StatelessWidget {
  final bool visible;
  final bool enabled;
  final VoidCallback? onPressed;

  const _QrToggleButton({
    required this.visible,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: enabled
            ? palette.textMuted
            : palette.textMuted.withValues(alpha: 0.4),
        backgroundColor: palette.surfaceMuted.withValues(alpha: 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      icon: Icon(visible ? Icons.visibility_off : Icons.qr_code_2, size: 18),
      label: Text(visible ? 'Hide' : 'Reveal'),
    );
  }
}

class _QrPreviewSummary extends StatelessWidget {
  final dynamic identity;

  const _QrPreviewSummary({required this.identity});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final displayName = identity?.displayName as String? ?? 'Unavailable';
    final fingerprint = identity?.fingerprint as String? ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.brand.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.qr_code_2, color: palette.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fingerprint.isEmpty ? 'Identity unavailable' : fingerprint,
                  style: TextStyle(color: palette.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemePresetChip extends StatelessWidget {
  final AppThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _ThemePresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final accent = switch (preset) {
      AppThemePreset.midnight => const Color(0xFF5B8CFF),
      AppThemePreset.graphite => const Color(0xFFD1D7E4),
      AppThemePreset.forest => const Color(0xFF57D8A0),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.16)
              : palette.surfaceMuted.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : palette.border.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preset.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preset.description,
                  style: TextStyle(color: palette.textMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RetentionChip extends StatelessWidget {
  final int value;
  final bool selected;
  final VoidCallback onTap;

  const _RetentionChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final label = switch (value) {
      retentionUnlimited => 'Keep all',
      250 => '250 msgs',
      1000 => '1,000 msgs',
      5000 => '5,000 msgs',
      _ => '$value msgs',
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? palette.brand.withValues(alpha: 0.16)
              : palette.surfaceMuted.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? palette.brand.withValues(alpha: 0.42)
                : palette.border.withValues(alpha: 0.22),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : palette.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
