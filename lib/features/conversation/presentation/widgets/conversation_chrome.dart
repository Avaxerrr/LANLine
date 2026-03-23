import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';

class ConversationTitle extends StatelessWidget {
  final String title;
  final String conversationType;
  final AsyncValue<List<ConversationMemberRow>> membersAsync;

  const ConversationTitle({
    super.key,
    required this.title,
    required this.conversationType,
    required this.membersAsync,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = conversationType == 'group'
        ? membersAsync.maybeWhen(
            data: (members) => '${members.length} members',
            orElse: () => 'Group chat',
          )
        : 'Direct conversation';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class ConversationEmptyState extends StatelessWidget {
  final bool isGroup;

  const ConversationEmptyState({super.key, required this.isGroup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isGroup ? Icons.groups_2_outlined : Icons.forum_outlined,
              size: 48,
              color: isGroup ? Colors.amber : Colors.blueAccent,
            ),
            const SizedBox(height: 16),
            Text(
              isGroup ? 'No group messages yet' : 'No messages yet',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isGroup
                  ? 'When invited members accept, this thread becomes your shared group chat.'
                  : 'Send the first message or share a file to start this conversation.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class ConversationError extends StatelessWidget {
  final String message;

  const ConversationError({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class GroupConversationNotice extends StatelessWidget {
  const GroupConversationNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Admin-only group settings. Group calls and file sharing can be added later.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}

class PinnedMessageBanner extends StatelessWidget {
  final String preview;
  final VoidCallback onUnpin;

  const PinnedMessageBanner({
    super.key,
    required this.preview,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(
              color: Colors.amber.withValues(alpha: 0.85),
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.push_pin_outlined, color: Colors.amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pinned message',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onUnpin,
              icon: const Icon(Icons.close, color: Colors.grey),
              tooltip: 'Unpin',
            ),
          ],
        ),
      ),
    );
  }
}
