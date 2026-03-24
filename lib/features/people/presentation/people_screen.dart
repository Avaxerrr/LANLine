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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        contactsAsync.when(
          data: (contacts) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (contacts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                        for (final peer in contacts)
                          _ContactCard(
                            peer: peer,
                            onTap: () {
                              unawaited(
                                _openConversation(
                                  context,
                                  conversationActions: conversationActions,
                                  peerId: peer.peerId,
                                  title: peer.displayName,
                                ),
                              );
                            },
                            onSelected: (action) {
                              switch (action) {
                                case _ContactMenuAction.chat:
                                  unawaited(
                                    _openConversation(
                                      context,
                                      conversationActions: conversationActions,
                                      peerId: peer.peerId,
                                      title: peer.displayName,
                                    ),
                                  );
                                  break;
                                case _ContactMenuAction.block:
                                  unawaited(
                                    runPeerAction(
                                      'Blocked ${peer.displayName}',
                                      () => requestActions.blockPeer(
                                        peerId: peer.peerId,
                                      ),
                                    ),
                                  );
                                  break;
                              }
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
      ],
    );
  }

  Future<void> _openConversation(
    BuildContext context, {
    required ConversationActions conversationActions,
    required String peerId,
    required String title,
  }) async {
    final conversation = await conversationActions.openDirectConversation(
      peerId: peerId,
      title: title,
    );

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectConversationScreen(
          conversationId: conversation.id,
          peerId: peerId,
          title: title,
          conversationType: conversation.type,
        ),
      ),
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
            const Color(0xFF1A2432).withValues(alpha: 0.88),
            const Color(0xFF151D28).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
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

enum _ContactMenuAction { chat, block }

class _ContactCard extends StatelessWidget {
  final PeerRow peer;
  final VoidCallback onTap;
  final ValueChanged<_ContactMenuAction> onSelected;

  const _ContactCard({
    required this.peer,
    required this.onTap,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF4DE1A7);
    final deviceLabel = peer.deviceLabel?.trim();
    final fingerprint = peer.fingerprint?.trim();
    final subtitleParts = <String>[
      if (deviceLabel != null && deviceLabel.isNotEmpty) deviceLabel,
      if (peer.lastSeenAt != null)
        _formatLastSeen(peer.lastSeenAt!)
      else if (fingerprint != null && fingerprint.isNotEmpty)
        fingerprint,
    ];

    final subtitle = subtitleParts.isEmpty
        ? 'Ready to chat'
        : subtitleParts.join(' | ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2432).withValues(alpha: 0.88),
            const Color(0xFF151D28).withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: peer.lastSeenAt != null
                              ? accent
                              : Colors.white24,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF151B26),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 13),
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
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<_ContactMenuAction>(
                  tooltip: 'Contact options',
                  icon: const Icon(Icons.more_horiz, color: Colors.white38),
                  color: const Color(0xFF202734),
                  onSelected: onSelected,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _ContactMenuAction.chat,
                      child: _ContactMenuRow(
                        icon: Icons.chat_bubble_outline,
                        label: 'Open chat',
                      ),
                    ),
                    PopupMenuItem(
                      value: _ContactMenuAction.block,
                      child: _ContactMenuRow(
                        icon: Icons.block_outlined,
                        label: 'Block contact',
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _initialsFor(String name) {
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
}

class _ContactMenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _ContactMenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final rowColor = color ?? Colors.white;
    return Row(
      children: [
        Icon(icon, size: 18, color: rowColor),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: rowColor)),
      ],
    );
  }
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
