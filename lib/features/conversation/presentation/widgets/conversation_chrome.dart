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
    final isGroup = conversationType == 'group';
    final subtitle = isGroup
        ? membersAsync.maybeWhen(
            data: (members) => '${members.length} members',
            orElse: () => 'Group chat',
          )
        : 'Direct conversation';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isGroup
                    ? Colors.amber.withValues(alpha: 0.14)
                    : Colors.blueAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                isGroup ? 'Group' : 'Direct',
                style: TextStyle(
                  color: isGroup ? Colors.amber : Colors.blueAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
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
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: (isGroup ? Colors.amber : Colors.blueAccent).withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGroup ? Icons.groups_2_outlined : Icons.forum_outlined,
                size: 34,
                color: isGroup ? Colors.amber : Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isGroup ? 'No group messages yet' : 'No messages yet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              isGroup
                  ? 'When invited members accept, this thread becomes your shared group chat.'
                  : 'Send the first message or share a file to start this conversation.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, height: 1.4),
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
          style: const TextStyle(color: Colors.redAccent, height: 1.35),
        ),
      ),
    );
  }
}

class GroupConversationNotice extends StatelessWidget {
  const GroupConversationNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF151B26),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.groups_2_outlined, color: Colors.amber, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Admin-only group settings. Group calls and file sharing can be added later.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
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
          color: const Color(0xFF151B26),
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
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.push_pin_outlined,
                color: Colors.amber,
                size: 16,
              ),
            ),
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
                    style: const TextStyle(color: Colors.grey, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onUnpin,
              style: TextButton.styleFrom(
                foregroundColor: Colors.amber,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: const Text('Unpin'),
            ),
          ],
        ),
      ),
    );
  }
}
