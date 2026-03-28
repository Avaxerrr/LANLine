import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swipeable_tile/swipeable_tile.dart';

import '../../../core/db/app_database.dart';
import '../../../core/providers/data_providers.dart';
import '../../../core/providers/identity_provider.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../call/presentation/call_screen.dart';
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
    final palette = context.appPalette;
    return Row(
      children: [
        Expanded(
          child: Text(
            conversationCount == 0
                ? 'Start from Requests to create a conversation.'
                : '$conversationCount conversation${conversationCount == 1 ? '' : 's'}',
            style: TextStyle(
              color: palette.textMuted.withValues(alpha: 0.92),
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
              foregroundColor: palette.brand.withValues(alpha: 0.92),
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

class _ConversationRow extends ConsumerWidget {
  final ConversationRow conversation;
  final VoidCallback onTap;

  const _ConversationRow({required this.conversation, required this.onTap});

  bool get _isDirect => conversation.type == 'direct';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final accent = conversation.type == 'group'
        ? palette.groupAccent
        : palette.brand;
    final title =
        conversation.title ??
        (conversation.type == 'group' ? 'Group chat' : 'Direct conversation');
    final preview = conversation.lastMessagePreview ?? 'No messages yet';

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SwipeableTile.swipeToTrigger(
      key: ValueKey(conversation.id),
      color: palette.surface,
      borderRadius: 22,
      swipeThreshold: 0.3,
      direction: _isDirect
          ? SwipeDirection.horizontal
          : SwipeDirection.endToStart,
      onSwiped: (direction) {
        HapticFeedback.mediumImpact();
        if (direction == SwipeDirection.startToEnd && _isDirect) {
          _startCall(context, ref, 'audio');
        } else if (direction == SwipeDirection.endToStart) {
          _confirmDelete(context, ref, title);
        }
      },
      backgroundBuilder: (context, direction, progress) {
        return AnimatedBuilder(
          animation: progress,
          builder: (context, _) {
            final value = progress.value;
            if (value < 0.01) return const SizedBox.shrink();
            final opacity = (value * 4).clamp(0.0, 1.0);
            final isCall = direction == SwipeDirection.startToEnd;
            return Opacity(
              opacity: opacity,
              child: Container(
                alignment: isCall
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: isCall ? palette.positive : palette.danger,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCall ? Icons.call : Icons.delete_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCall ? 'Call' : 'Delete',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      child: GestureDetector(
        onLongPressStart: (details) {
          HapticFeedback.mediumImpact();
          _showContextMenu(
            context,
            ref,
            position: details.globalPosition,
            title: title,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              decoration: BoxDecoration(
                gradient: palette.surfaceGradient,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: palette.border.withValues(alpha: 0.12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 15,
                ),
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
                            accent.withValues(alpha: 0.22),
                            accent.withValues(alpha: 0.06),
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
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
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
                                  style: TextStyle(
                                    color: palette.textMuted.withValues(
                                      alpha: 0.94,
                                    ),
                                    height: 1.28,
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (conversation.lastMessageAt != null)
                            Text(
                              _formatConversationTime(
                                conversation.lastMessageAt!,
                              ),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: palette.textMuted.withValues(
                                  alpha: 0.68,
                                ),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            const SizedBox(height: 14),
                          const SizedBox(height: 8),
                          if (conversation.unreadCount > 0)
                            Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: palette.brand,
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
                              color: palette.textMuted.withValues(alpha: 0.42),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref, {
    required Offset position,
    required String title,
  }) {
    final palette = context.appPalette;
    final items = <PopupMenuEntry<_ConversationAction>>[
      if (_isDirect) ...[
        PopupMenuItem(
          value: _ConversationAction.audioCall,
          child: Row(
            children: [
              Icon(Icons.call, size: 18, color: palette.positive),
              const SizedBox(width: 12),
              const Text('Audio call'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _ConversationAction.videoCall,
          child: Row(
            children: [
              Icon(Icons.videocam, size: 18, color: palette.positive),
              const SizedBox(width: 12),
              const Text('Video call'),
            ],
          ),
        ),
        const PopupMenuDivider(),
      ],
      PopupMenuItem(
        value: _ConversationAction.delete,
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18, color: palette.danger),
            const SizedBox(width: 12),
            Text('Delete', style: TextStyle(color: palette.danger)),
          ],
        ),
      ),
    ];

    showMenu<_ConversationAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: items,
    ).then((action) {
      if (action == null || !context.mounted) return;
      switch (action) {
        case _ConversationAction.audioCall:
          _startCall(context, ref, 'audio');
        case _ConversationAction.videoCall:
          _startCall(context, ref, 'video');
        case _ConversationAction.delete:
          _confirmDelete(context, ref, title);
      }
    });
  }

  Future<void> _startCall(
    BuildContext context,
    WidgetRef ref,
    String callType,
  ) async {
    if (!_isDirect) return;
    try {
      final peer = await ref.read(
        directConversationPeerProvider(conversation.id).future,
      );
      if (peer == null || !context.mounted) return;

      await ref.read(callSignalingActionsProvider).prepareOutgoingCall(
        peerId: peer.peerId,
        conversationId: conversation.id,
        conversationTitle: conversation.title ?? 'Direct conversation',
        callType: callType,
      );

      final localIdentity =
          await ref.read(identityServiceProvider).bootstrap();
      if (!context.mounted) return;

      final result = await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: 'call_${DateTime.now().millisecondsSinceEpoch}',
            myName: localIdentity.displayName,
            remoteDisplayName: conversation.title ?? 'Direct conversation',
            callType: callType,
            isInitiator: true,
            sendSignal: (payload) {
              unawaited(
                ref.read(callSignalingActionsProvider).sendCallSignal(
                  peerId: peer.peerId,
                  conversationId: conversation.id,
                  conversationTitle: conversation.title ?? 'Direct conversation',
                  payload: payload,
                ),
              );
            },
          ),
        ),
      );

      if (result != null && result > 0) {
        await ref.read(callSignalingActionsProvider).addLocalCallSummary(
          conversationId: conversation.id,
          callType: callType,
          durationSeconds: result,
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start call: $error')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final palette = context.appPalette;
        return AlertDialog(
          title: const Text('Delete conversation'),
          content: Text('Delete "$title" and all its messages? This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: palette.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(conversationsRepositoryProvider)
            .deleteConversation(conversation.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "$title"')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $error')),
          );
        }
      }
    }
  }
}

enum _ConversationAction { audioCall, videoCall, delete }

class _EmptyChatsState extends StatelessWidget {
  final VoidCallback? onGoToRequests;

  const _EmptyChatsState({this.onGoToRequests});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: palette.surfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: palette.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.forum_outlined, size: 42, color: palette.brand),
          ),
          const SizedBox(height: 18),
          const Text(
            'No chats yet',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Text(
            'Connect from Requests or create a small group when you are ready to start talking.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, height: 1.45),
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
    final palette = context.appPalette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: palette.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textMuted),
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
