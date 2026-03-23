import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/providers/v2_data_providers.dart';

class ForwardMessageSheet extends ConsumerWidget {
  final String currentConversationId;
  final ValueChanged<ConversationRow> onSelectConversation;

  const ForwardMessageSheet({
    super.key,
    required this.currentConversationId,
    required this.onSelectConversation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationListProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Forward To',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: conversationsAsync.when(
                data: (conversations) {
                  final targets = conversations
                      .where(
                        (conversation) =>
                            conversation.id != currentConversationId,
                      )
                      .toList();

                  if (targets.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: Text(
                          'No other chats available to forward into yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: targets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final conversation = targets[index];
                      final accent = conversation.type == 'group'
                          ? Colors.amber
                          : Colors.blueAccent;
                      return Card(
                        color: const Color(0xFF1B1B1B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: ListTile(
                          onTap: () => onSelectConversation(conversation),
                          leading: CircleAvatar(
                            backgroundColor: accent.withValues(alpha: 0.16),
                            child: Icon(
                              conversation.type == 'group'
                                  ? Icons.groups_2_outlined
                                  : Icons.chat_bubble_outline,
                              color: accent,
                            ),
                          ),
                          title: Text(
                            conversation.title ??
                                (conversation.type == 'group'
                                    ? 'Group chat'
                                    : 'Direct conversation'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            conversation.lastMessagePreview ??
                                'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: Text(
                      '$error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
