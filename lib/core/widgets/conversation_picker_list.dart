import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../providers/data_providers.dart';
import '../theme/app_theme.dart';

/// Reusable conversation list for picking a target conversation.
/// Used by the forward sheet, share target screen, and anywhere else
/// that needs a "pick a conversation" UI.
class ConversationPickerList extends ConsumerWidget {
  /// Called when the user taps a conversation.
  final ValueChanged<ConversationRow> onSelect;

  /// Optional conversation ID to exclude from the list.
  final String? excludeConversationId;

  /// If true, only direct conversations are shown.
  final bool directOnly;

  /// Trailing icon for each tile.
  final IconData trailingIcon;

  /// Message shown when no conversations match.
  final String emptyMessage;

  const ConversationPickerList({
    super.key,
    required this.onSelect,
    this.excludeConversationId,
    this.directOnly = false,
    this.trailingIcon = Icons.chevron_right,
    this.emptyMessage = 'No conversations available.',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final conversationsAsync = ref.watch(conversationListProvider);

    return conversationsAsync.when(
      data: (conversations) {
        var targets = conversations.where((c) {
          if (excludeConversationId != null && c.id == excludeConversationId) {
            return false;
          }
          if (directOnly && c.type != 'direct') return false;
          return true;
        }).toList();

        if (targets.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted),
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
                ? palette.groupAccent
                : palette.brand;
            return Container(
              decoration: BoxDecoration(
                gradient: palette.surfaceGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: palette.border.withValues(alpha: 0.18),
                ),
              ),
              child: ListTile(
                onTap: () => onSelect(conversation),
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
                  conversation.lastMessagePreview ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.textMuted),
                ),
                trailing: Icon(
                  trailingIcon,
                  color: palette.textMuted.withValues(alpha: 0.5),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '$error',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appPalette.danger),
          ),
        ),
      ),
    );
  }
}
