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
