import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/v2_data_providers.dart';
import '../../conversation/presentation/direct_conversation_screen.dart';

class ChatsScreen extends ConsumerWidget {
  final VoidCallback? onGoToRequests;

  const ChatsScreen({super.key, this.onGoToRequests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationListProvider);

    return conversationsAsync.when(
      data: (conversations) {
        if (conversations.isEmpty) {
          return _EmptyChatsState(onGoToRequests: onGoToRequests);
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: conversations.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return Card(
              color: const Color(0xFF1B1B1B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: ListTile(
                onTap: () => _openConversation(
                  context,
                  ref,
                  conversationId: conversation.id,
                  title: conversation.title ?? 'Direct conversation',
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.18),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.blueAccent,
                  ),
                ),
                title: Text(
                  conversation.title ?? 'Direct conversation',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  conversation.lastMessagePreview ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: conversation.unreadCount > 0
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.blueAccent,
                        child: Text(
                          '${conversation.unreadCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.chevron_right, color: Colors.grey),
              ),
            );
          },
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
    required String conversationId,
    required String title,
  }) async {
    final peer = await ref.read(
      directConversationPeerProvider(conversationId).future,
    );
    if (peer == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectConversationScreen(
          conversationId: conversationId,
          peerId: peer.peerId,
          title: peer.displayName,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forum_outlined,
                size: 52,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No chats yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Direct conversations will appear here once you connect from the Requests tab.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onGoToRequests,
              icon: const Icon(Icons.inbox_outlined),
              label: const Text('Open Requests'),
            ),
          ],
        ),
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
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
