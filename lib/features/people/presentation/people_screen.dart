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
        const _SectionHeader(
          title: 'Contacts',
          subtitle: 'Your approved contacts live here.',
        ),
        const SizedBox(height: 16),
        contactsAsync.when(
          data: (contacts) => contacts.isEmpty
              ? const _SectionPlaceholder(
                  icon: Icons.people_alt_outlined,
                  text: 'No contacts yet',
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
    final accent = Colors.greenAccent;
    final subtitleParts = <String>[
      if (peer.deviceLabel != null && peer.deviceLabel!.trim().isNotEmpty)
        peer.deviceLabel!.trim(),
      if (peer.fingerprint != null && peer.fingerprint!.trim().isNotEmpty)
        peer.fingerprint!.trim(),
    ];

    final subtitle = subtitleParts.isEmpty
        ? 'Tap to open chat'
        : subtitleParts.join('  •  ');

    return Card(
      color: const Color(0xFF1B1B1B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: accent.withValues(alpha: 0.16),
              child: Text(
                _initialsFor(peer.displayName),
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(
              peer.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            trailing: PopupMenuButton<_ContactMenuAction>(
              tooltip: 'Contact options',
              icon: const Icon(Icons.more_horiz, color: Colors.grey),
              color: const Color(0xFF252525),
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

  const _ContactMenuRow({
    required this.icon,
    required this.label,
    this.color,
  });

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
