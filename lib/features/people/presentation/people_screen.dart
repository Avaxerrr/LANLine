import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/v2_data_providers.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);
    final discoveredAsync = ref.watch(discoveredPeersProvider);
    final requestActions = ref.read(requestActionsProvider);

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _SectionHeader(
          title: 'Contacts',
          subtitle: 'Approved peers will appear here.',
        ),
        const SizedBox(height: 12),
        contactsAsync.when(
          data: (contacts) => contacts.isEmpty
              ? const _SectionPlaceholder(
                  icon: Icons.people_alt_outlined,
                  text: 'No contacts yet',
                )
              : Column(
                  children: [
                    for (final peer in contacts)
                      _PeerCard(
                        title: peer.displayName,
                        subtitle:
                            peer.deviceLabel ??
                            peer.fingerprint ??
                            'Accepted contact',
                        statusLabel: peer.relationshipState,
                        accent: Colors.greenAccent,
                        icon: Icons.verified_user_outlined,
                        actions: [
                          _ActionButton(
                            label: 'Block',
                            icon: Icons.block_outlined,
                            foreground: Colors.redAccent,
                            onPressed: () {
                              unawaited(
                                runPeerAction(
                                  'Blocked ${peer.displayName}',
                                  () => requestActions.blockPeer(
                                    peerId: peer.peerId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                  ],
                ),
          loading: () => const _SectionLoading(),
          error: (error, stackTrace) =>
              _SectionPlaceholder(icon: Icons.error_outline, text: '$error'),
        ),
        const SizedBox(height: 28),
        const _SectionHeader(
          title: 'Nearby / Discovered',
          subtitle: 'Request actions are now wired to local state.',
        ),
        const SizedBox(height: 12),
        discoveredAsync.when(
          data: (peers) => peers.isEmpty
              ? const _SectionPlaceholder(
                  icon: Icons.radar_outlined,
                  text: 'No discovered peers yet',
                )
              : Column(
                  children: [
                    for (final peer in peers)
                      _PeerCard(
                        title: peer.displayName,
                        subtitle:
                            peer.deviceLabel ??
                            peer.fingerprint ??
                            peer.relationshipState,
                        statusLabel: _relationshipLabel(peer.relationshipState),
                        accent: _accentForRelationship(peer.relationshipState),
                        icon: _iconForRelationship(peer.relationshipState),
                        actions: _actionsForPeer(
                          peer: peer,
                          requestActions: requestActions,
                          runPeerAction: runPeerAction,
                        ),
                      ),
                  ],
                ),
          loading: () => const _SectionLoading(),
          error: (error, stackTrace) =>
              _SectionPlaceholder(icon: Icons.error_outline, text: '$error'),
        ),
      ],
    );
  }

  List<Widget> _actionsForPeer({
    required PeerRow peer,
    required RequestActions requestActions,
    required Future<void> Function(
      String successMessage,
      Future<void> Function() action,
    )
    runPeerAction,
  }) {
    switch (peer.relationshipState) {
      case 'pending_incoming':
      case 'pending_outgoing':
        return [
          _ActionButton(
            label: 'Block',
            icon: Icons.block_outlined,
            foreground: Colors.redAccent,
            outlined: true,
            onPressed: () {
              unawaited(
                runPeerAction(
                  'Blocked ${peer.displayName}',
                  () => requestActions.blockPeer(peerId: peer.peerId),
                ),
              );
            },
          ),
        ];
      case 'accepted':
        return [
          _ActionButton(
            label: 'Block',
            icon: Icons.block_outlined,
            foreground: Colors.redAccent,
            outlined: true,
            onPressed: () {
              unawaited(
                runPeerAction(
                  'Blocked ${peer.displayName}',
                  () => requestActions.blockPeer(peerId: peer.peerId),
                ),
              );
            },
          ),
        ];
      case 'blocked':
        return const [];
      default:
        return [
          _ActionButton(
            label: 'Connect',
            icon: Icons.person_add_alt_1_outlined,
            foreground: Colors.greenAccent,
            onPressed: () {
              unawaited(
                runPeerAction(
                  'Request sent to ${peer.displayName}',
                  () =>
                      requestActions.sendConnectionRequest(peerId: peer.peerId),
                ),
              );
            },
          ),
          _ActionButton(
            label: 'Block',
            icon: Icons.block_outlined,
            foreground: Colors.redAccent,
            outlined: true,
            onPressed: () {
              unawaited(
                runPeerAction(
                  'Blocked ${peer.displayName}',
                  () => requestActions.blockPeer(peerId: peer.peerId),
                ),
              );
            },
          ),
        ];
    }
  }

  static String _relationshipLabel(String relationshipState) {
    switch (relationshipState) {
      case 'pending_incoming':
        return 'Incoming request';
      case 'pending_outgoing':
        return 'Request sent';
      case 'accepted':
        return 'Contact';
      case 'blocked':
        return 'Blocked';
      default:
        return 'Nearby';
    }
  }

  static Color _accentForRelationship(String relationshipState) {
    switch (relationshipState) {
      case 'pending_incoming':
        return Colors.blueAccent;
      case 'pending_outgoing':
        return Colors.orangeAccent;
      case 'accepted':
        return Colors.greenAccent;
      case 'blocked':
        return Colors.redAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  static IconData _iconForRelationship(String relationshipState) {
    switch (relationshipState) {
      case 'pending_incoming':
        return Icons.call_received;
      case 'pending_outgoing':
        return Icons.call_made;
      case 'accepted':
        return Icons.verified_user_outlined;
      case 'blocked':
        return Icons.block_outlined;
      default:
        return Icons.wifi_tethering_outlined;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _SectionPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionPlaceholder({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.grey)),
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

class _PeerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String statusLabel;
  final Color accent;
  final IconData icon;
  final List<Widget> actions;

  const _PeerCard({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.accent,
    required this.icon,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1B1B1B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accent.withValues(alpha: 0.16),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                _StatusChip(label: statusLabel, accent: accent),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _StatusChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color foreground;
  final VoidCallback onPressed;
  final bool outlined;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );

    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(foregroundColor: foreground),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: foreground.withValues(alpha: 0.16),
        foregroundColor: foreground,
      ),
      child: child,
    );
  }
}
