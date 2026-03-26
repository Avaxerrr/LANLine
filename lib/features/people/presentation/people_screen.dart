import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/network/discovery_service.dart';
import '../../../core/network/v2_request_signaling_service.dart';
import '../../../core/providers/v2_data_providers.dart';
import '../../../core/providers/v2_presence_discovery_provider.dart';
import '../../../core/providers/v2_repository_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../conversation/presentation/direct_conversation_screen.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);
    final requestActions = ref.read(requestActionsProvider);
    final conversationActions = ref.read(conversationActionsProvider);
    final palette = context.appPalette;

    Future<void> runPeerAction(
      String successMessage,
      Future<void> Function() action,
    ) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
        messenger.showSnackBar(SnackBar(content: Text(successMessage)));
      } catch (error) {
        messenger.showSnackBar(
          SnackBar(content: Text('Action failed: $error')),
        );
      }
    }

    Future<void> openConversation(PeerRow peer) async {
      final conversation = await conversationActions.openDirectConversation(
        peerId: peer.peerId,
        title: peer.displayName,
      );

      if (!context.mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DirectConversationScreen(
            conversationId: conversation.id,
            peerId: peer.peerId,
            title: peer.displayName,
            conversationType: conversation.type,
          ),
        ),
      );
    }

    Future<void> showContactSheet(PeerRow peer) async {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: palette.menuSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (sheetContext) {
          final deviceLabel = peer.deviceLabel?.trim();
          final fingerprint = peer.fingerprint?.trim();
          final details = <_ContactDetailLine>[
            if (deviceLabel != null && deviceLabel.isNotEmpty)
              _ContactDetailLine(
                icon: Icons.devices_outlined,
                label: 'Device',
                value: deviceLabel,
              ),
            if (fingerprint != null && fingerprint.isNotEmpty)
              _ContactDetailLine(
                icon: Icons.verified_user_outlined,
                label: 'Fingerprint',
                value: fingerprint,
              ),
            _ContactDetailLine(
              icon: Icons.schedule_outlined,
              label: 'Availability',
              value: peer.lastSeenAt != null
                  ? _formatLastSeen(peer.lastSeenAt!)
                  : 'Not seen recently',
            ),
          ];

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: palette.positive.withValues(alpha: 0.16),
                      child: Text(
                        _initialsFor(peer.displayName),
                        style: TextStyle(
                          color: palette.positive,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            peer.displayName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            peer.lastSeenAt != null
                                ? 'Contact available on your network'
                                : 'Saved contact',
                            style: TextStyle(
                              color: palette.textMuted,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    gradient: palette.surfaceGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: palette.border.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < details.length; index++) ...[
                        _ContactDetailRow(detail: details[index]),
                        if (index != details.length - 1)
                          Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await openConversation(peer);
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Message'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await runPeerAction(
                            'Blocked ${peer.displayName}',
                            () => requestActions.blockPeer(peerId: peer.peerId),
                          );
                        },
                        icon: const Icon(Icons.block_outlined),
                        label: const Text('Block'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _showTunnelSettingsSheet(context, ref, peer);
                        },
                        icon: const Icon(Icons.route_outlined),
                        label: Text(
                          peer.useTunnel
                              ? 'Connection (Tunnel)'
                              : 'Connection (LAN)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          await runPeerAction(
                            'Removed ${peer.displayName}',
                            () => ref
                                .read(peersRepositoryProvider)
                                .removePeer(peer.peerId),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.danger,
                        ),
                        icon: const Icon(Icons.person_remove_outlined),
                        label: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 138),
      children: [
        contactsAsync.when(
          data: (contacts) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contacts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    '${contacts.length} contact${contacts.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              contacts.isEmpty
                  ? const _SectionPlaceholder(
                      icon: Icons.people_alt_outlined,
                      text:
                          'Approve a nearby device from Requests and it will appear here.',
                    )
                  : Column(
                      children: [
                        for (
                          var index = 0;
                          index < contacts.length;
                          index++
                        ) ...[
                          _ContactRow(
                            peer: contacts[index],
                            onTap: () =>
                                unawaited(showContactSheet(contacts[index])),
                          ),
                          if (index != contacts.length - 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 72),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                        ],
                      ],
                    ),
            ],
          ),
          loading: () => const _SectionLoading(),
          error: (error, stackTrace) =>
              _SectionPlaceholder(icon: Icons.error_outline, text: '$error'),
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => _showAddByIpDialog(context, ref),
            icon: const Icon(Icons.add_link),
            label: const Text('Add peer by IP'),
          ),
        ),
      ],
    );
  }
}

void _showAddByIpDialog(BuildContext context, WidgetRef ref) {
  final hostController = TextEditingController();
  final portController = TextEditingController(
    text: V2RequestSignalingService.defaultPort.toString(),
  );
  final palette = context.appPalette;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: palette.menuSurface,
      title: const Text('Add peer by IP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: hostController,
            decoration: const InputDecoration(
              labelText: 'Tailscale / tunnel IP',
              hintText: '100.x.x.x',
            ),
            keyboardType: TextInputType.number,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: portController,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final host = hostController.text.trim();
            if (host.isEmpty) return;
            final port = int.tryParse(portController.text.trim());
            Navigator.pop(dialogContext);

            final messenger = ScaffoldMessenger.of(context);
            messenger.showSnackBar(
              const SnackBar(content: Text('Discovering peer...')),
            );

            final discovery = ref.read(
              v2PresenceDiscoveryControllerProvider,
            );
            final result = await discovery.discoverPeerByIp(
              host: host,
              port: port,
            );
            if (result == null) {
              messenger.clearSnackBars();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Could not reach peer. Make sure LANLine is running '
                    'on that device and the IP is not your own.',
                  ),
                ),
              );
              return;
            }

            final peersRepo = ref.read(peersRepositoryProvider);
            await peersRepo.upsertPeer(
              peerId: result.peerId,
              displayName: result.displayName,
              deviceLabel: result.deviceLabel,
              fingerprint: result.fingerprint,
              relationshipState: 'discovered',
              isBlocked: false,
            );
            await peersRepo.saveTunnelSettings(
              peerId: result.peerId,
              useTunnel: true,
              tunnelHost: host,
              tunnelPort: port,
            );
            final now = DateTime.now().millisecondsSinceEpoch;
            await peersRepo.upsertPresence(
              peerId: result.peerId,
              status: 'online',
              isReachable: true,
              transportType: 'tunnel',
              host: host,
              port: port ?? V2RequestSignalingService.defaultPort,
              lastHeartbeatAt: now,
              lastProbeAt: now,
            );

            messenger.clearSnackBars();
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'Found ${result.displayName}! Send them a connection request from Requests.',
                ),
              ),
            );
          },
          child: const Text('Discover'),
        ),
      ],
    ),
  );
}

void _showTunnelSettingsSheet(
  BuildContext context,
  WidgetRef ref,
  PeerRow peer,
) {
  final palette = context.appPalette;
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: palette.menuSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
    ),
    builder: (sheetContext) => _TunnelSettingsSheet(
      peer: peer,
      parentRef: ref,
    ),
  );
}

class _TunnelSettingsSheet extends StatefulWidget {
  final PeerRow peer;
  final WidgetRef parentRef;

  const _TunnelSettingsSheet({required this.peer, required this.parentRef});

  @override
  State<_TunnelSettingsSheet> createState() => _TunnelSettingsSheetState();
}

class _TunnelSettingsSheetState extends State<_TunnelSettingsSheet> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late bool _useTunnel;
  List<({String label, String address})> _localInterfaces = [];

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(
      text: widget.peer.tunnelHost ?? '',
    );
    _portController = TextEditingController(
      text: widget.peer.tunnelPort?.toString() ??
          V2RequestSignalingService.defaultPort.toString(),
    );
    _useTunnel = widget.peer.useTunnel;
    _loadInterfaces();
  }

  Future<void> _loadInterfaces() async {
    final discoveryService = widget.parentRef.read(discoveryServiceProvider);
    final interfaces = await discoveryService.listLocalInterfaces();
    if (mounted) {
      setState(() => _localInterfaces = interfaces);
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection — ${widget.peer.displayName}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          // Your device IPs
          Text(
            'Your device addresses',
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_localInterfaces.isEmpty)
            Text(
              'Detecting...',
              style: TextStyle(color: palette.textMuted, fontSize: 13),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: palette.surfaceGradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.border.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _localInterfaces.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _interfaceIcon(_localInterfaces[i].label),
                            color: palette.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _localInterfaces[i].label,
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _localInterfaces[i].address,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i != _localInterfaces.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Share your Tailscale/VPN address with the other device so '
            'they can enter it in their tunnel settings.',
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          // Tunnel toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Use tunnel',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _useTunnel
                  ? 'Messages will be sent to the tunnel address below'
                  : 'Messages will be sent via LAN discovery',
              style: TextStyle(color: palette.textMuted, fontSize: 12.5),
            ),
            value: _useTunnel,
            onChanged: (value) => setState(() => _useTunnel = value),
          ),
          if (_useTunnel) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _hostController,
              decoration: InputDecoration(
                labelText:
                    "${widget.peer.displayName}'s Tailscale / tunnel IP",
                hintText: '100.x.x.x or device.tailnet.ts.net',
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Port',
                hintText: V2RequestSignalingService.defaultPort.toString(),
              ),
              textInputAction: TextInputAction.done,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final trimmedHost = _hostController.text.trim();
    final trimmedPort = _portController.text.trim();
    final port = trimmedPort.isEmpty
        ? V2RequestSignalingService.defaultPort
        : int.tryParse(trimmedPort);

    if (_useTunnel && trimmedHost.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Enter a host or IP for tunnel mode.'),
        ),
      );
      return;
    }
    if (port == null || port < 1 || port > 65535) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Port must be between 1 and 65535.')),
      );
      return;
    }

    final peersRepository = widget.parentRef.read(peersRepositoryProvider);
    await peersRepository.saveTunnelSettings(
      peerId: widget.peer.peerId,
      useTunnel: _useTunnel,
      tunnelHost: _useTunnel ? trimmedHost : widget.peer.tunnelHost,
      tunnelPort: _useTunnel
          ? (port == V2RequestSignalingService.defaultPort ? null : port)
          : widget.peer.tunnelPort,
    );

    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _useTunnel
              ? 'Tunnel enabled for ${widget.peer.displayName}'
              : 'Switched to LAN for ${widget.peer.displayName}',
        ),
      ),
    );
  }

  static IconData _interfaceIcon(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('tailscale') || normalized.contains('100.')) {
      return Icons.vpn_lock_outlined;
    }
    if (normalized.contains('wi-fi') ||
        normalized.contains('wifi') ||
        normalized.contains('wlan')) {
      return Icons.wifi;
    }
    if (normalized.contains('ethernet') || normalized.contains('eth')) {
      return Icons.settings_ethernet;
    }
    if (normalized.contains('vpn') ||
        normalized.contains('tun') ||
        normalized.contains('wg')) {
      return Icons.vpn_lock_outlined;
    }
    return Icons.lan_outlined;
  }
}

class _SectionPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionPlaceholder({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: palette.surfaceGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.surfaceMuted.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: palette.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: palette.textMuted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final PeerRow peer;
  final VoidCallback onTap;

  const _ContactRow({
    required this.peer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final accent = palette.positive;
    final secondary = _contactSecondary(peer);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: accent.withValues(alpha: 0.14),
                    child: Text(
                      _initialsFor(peer.displayName),
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: peer.lastSeenAt != null
                            ? accent
                            : palette.textMuted.withValues(alpha: 0.28),
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      peer.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: palette.textMuted.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _contactSecondary(PeerRow peer) {
    final deviceLabel = peer.deviceLabel?.trim();
    final parts = <String>[
      if (deviceLabel != null && deviceLabel.isNotEmpty) deviceLabel,
      if (peer.lastSeenAt != null)
        _formatLastSeen(peer.lastSeenAt!)
      else
        'Saved contact',
    ];
    return parts.join(' | ');
  }
}


class _ContactDetailRow extends StatelessWidget {
  final _ContactDetailLine detail;

  const _ContactDetailRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(detail.icon, color: palette.textMuted, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              detail.label,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              detail.value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactDetailLine {
  final IconData icon;
  final String label;
  final String value;

  const _ContactDetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });
}

String _formatLastSeen(int timestamp) {
  final difference = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(timestamp),
  );
  if (difference.inMinutes < 2) return 'Online recently';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}

String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}
