import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/v2_data_providers.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveredAsync = ref.watch(discoveredPeersProvider);
    final incomingAsync = ref.watch(pendingIncomingRequestsProvider);
    final outgoingAsync = ref.watch(pendingOutgoingRequestsProvider);
    final groupInvitesAsync = ref.watch(pendingGroupInvitesProvider);
    final requestActions = ref.read(requestActionsProvider);
    final conversationActions = ref.read(conversationActionsProvider);

    Future<void> runRequestAction(
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
          title: 'Requests',
          subtitle:
              'Discover nearby devices, approve people, and manage pending invitations.',
        ),
        const SizedBox(height: 16),
        _SectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Nearby devices',
                subtitle: 'Only devices you have not added yet appear here.',
              ),
              const SizedBox(height: 14),
              discoveredAsync.when(
                data: (peers) => peers.isEmpty
                    ? const _EmptyState(
                        icon: Icons.radar_outlined,
                        text: 'No new nearby devices right now',
                      )
                    : Column(
                        children: [
                          for (final peer in peers)
                            _NearbyPeerCard(
                              peer: peer,
                              onConnect: () {
                                unawaited(
                                  runRequestAction(
                                    'Request sent to ${peer.displayName}',
                                    () => requestActions.sendConnectionRequest(
                                      peerId: peer.peerId,
                                    ),
                                  ),
                                );
                              },
                              onBlock: () {
                                unawaited(
                                  runRequestAction(
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
                loading: () => const _SectionLoading(),
                error: (error, stackTrace) =>
                    _EmptyState(icon: Icons.error_outline, text: '$error'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Incoming requests',
                subtitle: 'Approve, decline, or block people who want to connect.',
              ),
              const SizedBox(height: 14),
              incomingAsync.when(
                data: (requests) => requests.isEmpty
                    ? const _EmptyState(
                        icon: Icons.mark_email_unread_outlined,
                        text: 'No incoming requests',
                      )
                    : Column(
                        children: [
                          for (final request in requests)
                            _PendingRequestCard(
                              title: request.peerId,
                              subtitle:
                                  request.message ??
                                  'This device wants to connect with you.',
                              accent: Colors.blueAccent,
                              statusLabel: 'Incoming',
                              actions: [
                                _ActionButton(
                                  label: 'Accept',
                                  icon: Icons.check_circle_outline,
                                  foreground: Colors.greenAccent,
                                  onPressed: () {
                                    unawaited(
                                      runRequestAction(
                                        'Accepted request from ${request.peerId}',
                                        () => requestActions.acceptRequest(
                                          request.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _ActionButton(
                                  label: 'Decline',
                                  icon: Icons.close_outlined,
                                  foreground: Colors.orangeAccent,
                                  outlined: true,
                                  onPressed: () {
                                    unawaited(
                                      runRequestAction(
                                        'Declined request from ${request.peerId}',
                                        () => requestActions.declineRequest(
                                          request.id,
                                        ),
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
                                      runRequestAction(
                                        'Blocked ${request.peerId}',
                                        () => requestActions.blockPeer(
                                          peerId: request.peerId,
                                          requestId: request.id,
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
                    _EmptyState(icon: Icons.error_outline, text: '$error'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Group invites',
                subtitle: 'Join or decline invitations to group chats.',
              ),
              const SizedBox(height: 14),
              groupInvitesAsync.when(
                data: (conversations) => conversations.isEmpty
                    ? const _EmptyState(
                        icon: Icons.groups_2_outlined,
                        text: 'No pending group invites',
                      )
                    : Column(
                        children: [
                          for (final conversation in conversations)
                            _PendingRequestCard(
                              title: conversation.title ?? 'Group invite',
                              subtitle:
                                  'Invitation pending for this conversation.',
                              accent: Colors.amber,
                              statusLabel: 'Invite',
                              actions: [
                                _ActionButton(
                                  label: 'Join',
                                  icon: Icons.check_circle_outline,
                                  foreground: Colors.greenAccent,
                                  onPressed: () {
                                    unawaited(
                                      runRequestAction(
                                        'Joined ${conversation.title ?? 'group'}',
                                        () =>
                                            conversationActions.acceptGroupInvite(
                                          conversation.id,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _ActionButton(
                                  label: 'Decline',
                                  icon: Icons.close_outlined,
                                  foreground: Colors.orangeAccent,
                                  outlined: true,
                                  onPressed: () {
                                    unawaited(
                                      runRequestAction(
                                        'Declined ${conversation.title ?? 'group'}',
                                        () =>
                                            conversationActions.declineGroupInvite(
                                          conversation.id,
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
                    _EmptyState(icon: Icons.error_outline, text: '$error'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _SectionSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                title: 'Outgoing requests',
                subtitle: 'Track requests you already sent.',
              ),
              const SizedBox(height: 14),
              outgoingAsync.when(
                data: (requests) => requests.isEmpty
                    ? const _EmptyState(
                        icon: Icons.outgoing_mail,
                        text: 'No outgoing requests',
                      )
                    : Column(
                        children: [
                          for (final request in requests)
                            _PendingRequestCard(
                              title: request.peerId,
                              subtitle:
                                  request.message ??
                                  'Waiting for this person to approve you.',
                              accent: Colors.orangeAccent,
                              statusLabel: 'Sent',
                              actions: [
                                _ActionButton(
                                  label: 'Cancel',
                                  icon: Icons.remove_circle_outline,
                                  foreground: Colors.orangeAccent,
                                  onPressed: () {
                                    unawaited(
                                      runRequestAction(
                                        'Cancelled request to ${request.peerId}',
                                        () => requestActions.cancelRequest(
                                          request.id,
                                        ),
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
                                      runRequestAction(
                                        'Blocked ${request.peerId}',
                                        () => requestActions.blockPeer(
                                          peerId: request.peerId,
                                          requestId: request.id,
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
                    _EmptyState(icon: Icons.error_outline, text: '$error'),
              ),
            ],
          ),
        ),
      ],
    );
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

class _SectionSurface extends StatelessWidget {
  final Widget child;

  const _SectionSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
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
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _NearbyPeerCard extends StatelessWidget {
  final PeerRow peer;
  final VoidCallback onConnect;
  final VoidCallback onBlock;

  const _NearbyPeerCard({
    required this.peer,
    required this.onConnect,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (peer.deviceLabel != null && peer.deviceLabel!.trim().isNotEmpty)
        peer.deviceLabel!.trim(),
      if (peer.fingerprint != null && peer.fingerprint!.trim().isNotEmpty)
        peer.fingerprint!.trim(),
    ];

    final subtitle = subtitleParts.isEmpty ? 'Reachable right now' : subtitleParts.join('  •  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.cyanAccent.withValues(alpha: 0.14),
            child: Text(
              _initialsFor(peer.displayName),
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onConnect,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.greenAccent.withValues(alpha: 0.18),
              foregroundColor: Colors.greenAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: const Text('Connect'),
          ),
          PopupMenuButton<_NearbyMenuAction>(
            tooltip: 'More actions',
            color: const Color(0xFF252525),
            onSelected: (action) {
              if (action == _NearbyMenuAction.block) {
                onBlock();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _NearbyMenuAction.block,
                child: _PopupMenuRow(
                  icon: Icons.block_outlined,
                  label: 'Block device',
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _NearbyMenuAction { block }

class _PendingRequestCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final String statusLabel;
  final List<Widget> actions;

  const _PendingRequestCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.statusLabel,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
              const SizedBox(width: 12),
              _StatusPill(label: statusLabel, accent: accent),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color accent;

  const _StatusPill({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
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

class _PopupMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PopupMenuRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
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
