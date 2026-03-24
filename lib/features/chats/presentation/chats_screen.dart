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

    return Stack(
      children: [
        conversationsAsync.when(
          data: (conversations) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _ChatsSummary(
                  conversationCount: conversations.length,
                  onGoToRequests: onGoToRequests,
                ),
                const SizedBox(height: 12),
                if (conversations.isEmpty)
                  _EmptyChatsState(onGoToRequests: onGoToRequests)
                else ...[
                  for (
                    var index = 0;
                    index < conversations.length;
                    index++
                  ) ...[
                    _ConversationCard(
                      conversation: conversations[index],
                      onTap: () => _openConversation(
                        context,
                        ref,
                        conversation: conversations[index],
                      ),
                    ),
                    if (index != conversations.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _ErrorState(title: 'Could not load chats', message: '$error'),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            top: false,
            child: FloatingActionButton.small(
              onPressed: () => _openCreateGroup(context),
              backgroundColor: Colors.blueAccent,
              elevation: 8,
              tooltip: 'Create group',
              child: const Icon(Icons.group_add_outlined),
            ),
          ),
        ),
      ],
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

class _ChatsSummary extends StatelessWidget {
  final int conversationCount;
  final VoidCallback? onGoToRequests;

  const _ChatsSummary({
    required this.conversationCount,
    required this.onGoToRequests,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conversationCount == 0 ? 'No conversations yet' : 'Recent',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                conversationCount == 0
                    ? 'Connect from Requests to start a conversation.'
                    : '$conversationCount active conversation${conversationCount == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white60, height: 1.3),
              ),
            ],
          ),
        ),
        if (onGoToRequests != null)
          TextButton(onPressed: onGoToRequests, child: const Text('Requests')),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final ConversationRow conversation;
  final VoidCallback onTap;

  const _ConversationCard({required this.conversation, required this.onTap});

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
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFF151B26),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    conversation.type == 'group'
                        ? Icons.groups_2_outlined
                        : Icons.chat_bubble_outline,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (conversation.type == 'group')
                            _TypePill(label: 'Group', accent: accent),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (conversation.unreadCount > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
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
                    color: Colors.white.withValues(alpha: 0.35),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151B26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              size: 48,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onGoToRequests,
                icon: const Icon(Icons.inbox_outlined),
                label: const Text('Open Requests'),
              ),
            ],
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
