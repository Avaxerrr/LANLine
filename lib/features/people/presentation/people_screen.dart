import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          subtitle: 'Only approved contacts appear here.',
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
                            label: 'Chat',
                            icon: Icons.chat_bubble_outline,
                            foreground: Colors.blueAccent,
                            onPressed: () {
                              unawaited(
                                _openConversation(
                                  context,
                                  conversationActions: conversationActions,
                                  peerId: peer.peerId,
                                  title: peer.displayName,
                                ),
                              );
                            },
                          ),
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

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
    );

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
