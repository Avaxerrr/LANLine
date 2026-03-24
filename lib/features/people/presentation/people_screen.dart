import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/v2_data_providers.dart';
import '../../conversation/presentation/direct_conversation_screen.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsProvider);
    final requestActions = ref.read(requestActionsProvider);
    final conversationActions = ref.read(conversationActionsProvider);

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
        backgroundColor: const Color(0xFF162131),
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
                      backgroundColor: const Color(
                        0xFF4DE1A7,
                      ).withValues(alpha: 0.16),
                      child: Text(
                        _initialsFor(peer.displayName),
                        style: const TextStyle(
                          color: Color(0xFF4DE1A7),
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
                            style: const TextStyle(
                              color: Colors.white60,
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF202C3D).withValues(alpha: 0.95),
                        const Color(0xFF182230).withValues(alpha: 0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.03),
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
                    style: const TextStyle(
                      color: Colors.white60,
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
                            onSelected: (action) {
                              switch (action) {
                                case _ContactMenuAction.message:
                                  unawaited(openConversation(contacts[index]));
                                  break;
                                case _ContactMenuAction.block:
                                  unawaited(
                                    runPeerAction(
                                      'Blocked ${contacts[index].displayName}',
                                      () => requestActions.blockPeer(
                                        peerId: contacts[index].peerId,
                                      ),
                                    ),
                                  );
                                  break;
                              }
                            },
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF202C3D).withValues(alpha: 0.9),
            const Color(0xFF182230).withValues(alpha: 0.84),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
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
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.35),
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
  final ValueChanged<_ContactMenuAction> onSelected;

  const _ContactRow({
    required this.peer,
    required this.onTap,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF4DE1A7);
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
                      style: const TextStyle(
                        color: Color(0xFF4DE1A7),
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
                            : Colors.white24,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF182230),
                          width: 2,
                        ),
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
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<_ContactMenuAction>(
                tooltip: 'Contact actions',
                icon: const Icon(Icons.more_horiz, color: Colors.white38),
                onSelected: onSelected,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ContactMenuAction.message,
                    child: _ContactMenuItem(
                      icon: Icons.chat_bubble_outline,
                      label: 'Message',
                    ),
                  ),
                  PopupMenuItem(
                    value: _ContactMenuAction.block,
                    child: _ContactMenuItem(
                      icon: Icons.block_outlined,
                      label: 'Block',
                      color: Colors.redAccent,
                    ),
                  ),
                ],
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

enum _ContactMenuAction { message, block }

class _ContactMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _ContactMenuItem({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Colors.white;
    return Row(
      children: [
        Icon(icon, size: 18, color: resolvedColor),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: resolvedColor)),
      ],
    );
  }
}

class _ContactDetailRow extends StatelessWidget {
  final _ContactDetailLine detail;

  const _ContactDetailRow({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(detail.icon, color: Colors.white54, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              detail.label,
              style: const TextStyle(
                color: Colors.white54,
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
