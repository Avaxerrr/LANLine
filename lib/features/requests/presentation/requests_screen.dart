import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/v2_data_providers.dart';
import '../../../core/theme/app_theme.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 138),
      children: [
        _RequestSection(
          title: 'Nearby devices',
          subtitle: 'Only devices you have not added yet appear here.',
          child: discoveredAsync.when(
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
        ),
        const SizedBox(height: 20),
        _RequestSection(
          title: 'Incoming requests',
          subtitle: 'Approve, decline, or block people who want to connect.',
          child: incomingAsync.when(
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
                          accent: palette.brand,
                          statusLabel: 'Incoming',
                          icon: Icons.mark_email_unread_outlined,
                          actions: [
                            _ActionButton(
                              label: 'Accept',
                              icon: Icons.check_circle_outline,
                              foreground: palette.positive,
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
                              foreground: palette.warning,
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
                              foreground: palette.danger,
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
        ),
        const SizedBox(height: 20),
        _RequestSection(
          title: 'Group invites',
          subtitle: 'Join or decline invitations to group chats.',
          child: groupInvitesAsync.when(
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
                          subtitle: 'Invitation pending for this conversation.',
                          accent: palette.groupAccent,
                          statusLabel: 'Invite',
                          icon: Icons.groups_2_outlined,
                          actions: [
                            _ActionButton(
                              label: 'Join',
                              icon: Icons.check_circle_outline,
                              foreground: palette.positive,
                              onPressed: () {
                                unawaited(
                                  runRequestAction(
                                    'Joined ${conversation.title ?? 'group'}',
                                    () => conversationActions.acceptGroupInvite(
                                      conversation.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                            _ActionButton(
                              label: 'Decline',
                              icon: Icons.close_outlined,
                              foreground: palette.warning,
                              outlined: true,
                              onPressed: () {
                                unawaited(
                                  runRequestAction(
                                    'Declined ${conversation.title ?? 'group'}',
                                    () => conversationActions
                                        .declineGroupInvite(conversation.id),
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
        ),
        const SizedBox(height: 20),
        _RequestSection(
          title: 'Outgoing requests',
          subtitle: 'Track requests you already sent.',
          child: outgoingAsync.when(
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
                          accent: palette.warning,
                          statusLabel: 'Sent',
                          icon: Icons.outgoing_mail,
                          actions: [
                            _ActionButton(
                              label: 'Cancel',
                              icon: Icons.remove_circle_outline,
                              foreground: palette.warning,
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
                              foreground: palette.danger,
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
        ),
      ],
    );
  }
}

class _RequestSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _RequestSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: title, subtitle: subtitle),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(color: palette.textMuted, fontSize: 12.5),
        ),
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
    final palette = context.appPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: palette.surfaceGradient,
        borderRadius: BorderRadius.circular(18),
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
    final palette = context.appPalette;
    final deviceLabel = peer.deviceLabel?.trim();
    final fingerprint = peer.fingerprint?.trim();
    final subtitleParts = <String>[
      if (deviceLabel != null && deviceLabel.isNotEmpty) deviceLabel,
      if (fingerprint != null && fingerprint.isNotEmpty) fingerprint,
    ];

    final subtitle = subtitleParts.isEmpty
        ? 'Reachable right now'
        : subtitleParts.join(' | ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  palette.brand.withValues(alpha: 0.16),
                  palette.brand.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Center(
              child: Text(
                _initialsFor(peer.displayName),
                style: TextStyle(
                  color: palette.brand,
                  fontWeight: FontWeight.w800,
                ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onConnect,
            style: FilledButton.styleFrom(
              backgroundColor: palette.positive.withValues(alpha: 0.16),
              foregroundColor: palette.positive,
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            ),
            child: const Text('Connect'),
          ),
          PopupMenuButton<_NearbyMenuAction>(
            tooltip: 'More actions',
            onSelected: (action) {
              if (action == _NearbyMenuAction.block) {
                onBlock();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _NearbyMenuAction.block,
                child: _PopupMenuRow(
                  icon: Icons.block_outlined,
                  label: 'Block device',
                  color: palette.danger,
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
  final IconData icon;
  final List<Widget> actions;

  const _PendingRequestCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.statusLabel,
    required this.icon,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.textMuted,
                        height: 1.35,
                        fontSize: 13,
                      ),
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
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: foreground.withValues(alpha: 0.16),
        foregroundColor: foreground,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
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
