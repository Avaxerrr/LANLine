import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/theme/app_theme.dart';

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
    final palette = context.appPalette;
    final isGroup = conversationType == 'group';
    final subtitle = isGroup
        ? membersAsync.maybeWhen(
            data: (members) => '${members.length} members',
            orElse: () => null,
          )
        : null;

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
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: palette.textMuted),
          ),
        ],
      ],
    );
  }
}

class ConversationEmptyState extends StatelessWidget {
  final bool isGroup;

  const ConversationEmptyState({super.key, required this.isGroup});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: (isGroup ? palette.groupAccent : palette.brand)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGroup ? Icons.groups_2_outlined : Icons.forum_outlined,
                size: 34,
                color: isGroup ? palette.groupAccent : palette.brand,
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
              style: TextStyle(color: palette.textMuted, height: 1.4),
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
    final palette = context.appPalette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.danger, height: 1.35),
        ),
      ),
    );
  }
}

class GroupConversationNotice extends StatelessWidget {
  const GroupConversationNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.groups_2_outlined, color: palette.groupAccent, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Admin-only group settings. Group calls and file sharing can be added later.',
                style: TextStyle(
                  color: palette.textMuted,
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
    final palette = context.appPalette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(
              color: palette.groupAccent.withValues(alpha: 0.85),
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
                color: palette.groupAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                Icons.push_pin_outlined,
                color: palette.groupAccent,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pinned message',
                    style: TextStyle(
                      color: palette.groupAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.textMuted, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onUnpin,
              style: TextButton.styleFrom(
                foregroundColor: palette.groupAccent,
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
