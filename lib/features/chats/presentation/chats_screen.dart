import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/v2_data_providers.dart';
import '../../conversation/presentation/direct_conversation_screen.dart';
import '../../groups/presentation/create_group_screen.dart';

class ChatsScreen extends ConsumerWidget {
  final VoidCallback? onGoToRequests;

  const ChatsScreen({super.key, this.onGoToRequests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationListProvider);

    return conversationsAsync.when(
      data: (conversations) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 138),
          children: [
            _ChatsToolbar(
              conversationCount: conversations.length,
              onCreateGroup: () => _openCreateGroup(context),
            ),
            const SizedBox(height: 12),
            if (conversations.isEmpty)
              _EmptyChatsState(onGoToRequests: onGoToRequests)
            else ...[
              for (var index = 0; index < conversations.length; index++) ...[
                _ConversationRow(
                  conversation: conversations[index],
                  onTap: () => _openConversation(
                    context,
                    ref,
                    conversation: conversations[index],
                  ),
                ),
                if (index != conversations.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          _ErrorState(title: 'Could not load chats', message: '$error'),
    );
  }

  Future<void> _openConversation(
    BuildContext context,
    WidgetRef ref, {
    required ConversationRow conversation,
  }) async {
    String? peerId;
    if (conversation.type == 'direct') {
      final peer = await ref.read(
        directConversationPeerProvider(conversation.id).future,
      );
      peerId = peer?.peerId;
      if (peerId == null || !context.mounted) return;
    }

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectConversationScreen(
          conversationId: conversation.id,
          peerId: peerId,
          title: conversation.title ?? _defaultConversationTitle(conversation),
          conversationType: conversation.type,
        ),
      ),
    );
  }

  Future<void> _openCreateGroup(BuildContext context) async {
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
  }

  static String _defaultConversationTitle(ConversationRow conversation) {
    return conversation.type == 'group' ? 'Group chat' : 'Direct conversation';
  }
}

class _ChatsToolbar extends StatelessWidget {
  final int conversationCount;
  final VoidCallback? onCreateGroup;

  const _ChatsToolbar({
    required this.conversationCount,
    required this.onCreateGroup,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            conversationCount == 0
                ? 'Start from Requests to create a conversation.'
                : '$conversationCount conversation${conversationCount == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Colors.white60,
              height: 1.3,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onCreateGroup != null)
          TextButton(
            onPressed: onCreateGroup,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('New group'),
          ),
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final Color accent;

  const _TypePill({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final ConversationRow conversation;
  final VoidCallback onTap;

  const _ConversationRow({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = conversation.type == 'group'
        ? Colors.amber
        : Colors.blueAccent;
    final title =
        conversation.title ??
        (conversation.type == 'group' ? 'Group chat' : 'Direct conversation');
    final preview = conversation.lastMessagePreview ?? 'No messages yet';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF202C3D).withValues(alpha: 0.92),
                const Color(0xFF182230).withValues(alpha: 0.86),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.18),
                        accent.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: Icon(
                    conversation.type == 'group'
                        ? Icons.groups_2_outlined
                        : Icons.chat_bubble_outline,
                    color: accent,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (conversation.type == 'group') ...[
                            _TypePill(label: 'Group', accent: accent),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                height: 1.32,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 54,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatConversationTime(conversation.lastMessageAt!),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else
                        const SizedBox(height: 14),
                      const SizedBox(height: 10),
                      if (conversation.unreadCount > 0)
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChatsState extends StatelessWidget {
  final VoidCallback? onGoToRequests;

  const _EmptyChatsState({this.onGoToRequests});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF202C3D).withValues(alpha: 0.92),
            const Color(0xFF182230).withValues(alpha: 0.86),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              size: 42,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No chats yet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            'Connect from Requests or create a small group when you are ready to start talking.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onGoToRequests,
            icon: const Icon(Icons.inbox_outlined),
            label: const Text('Open Requests'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;

  const _ErrorState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatConversationTime(int timestamp) {
  final now = DateTime.now();
  final value = DateTime.fromMillisecondsSinceEpoch(timestamp);
  final difference = now.difference(value);
  if (difference.inDays >= 7) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[value.weekday - 1];
  }
  if (difference.inDays >= 1) {
    return difference.inDays == 1 ? 'Yesterday' : '${difference.inDays}d';
  }
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
