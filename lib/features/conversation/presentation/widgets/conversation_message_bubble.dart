import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/providers/data_providers.dart';
import '../../../../core/theme/app_theme.dart';
import 'attachment_message_content.dart';
import 'message_actions_menu.dart';
import 'text_message_content.dart';

String? latestOutgoingMessageId(
  List<MessageRow> messages,
  String? localPeerId,
) {
  if (localPeerId == null) return null;
  for (var index = messages.length - 1; index >= 0; index--) {
    final message = messages[index];
    if (message.senderPeerId == localPeerId && message.type != 'system') {
      return message.id;
    }
  }
  return null;
}

class ConversationMessageBubble extends ConsumerStatefulWidget {
  final MessageRow message;
  final bool isMe;
  final String? peerId;
  final bool isGroup;
  final String senderLabel;
  final Map<String, List<int>> downloadProgress;
  final bool showStatus;
  final MessageRow? repliedMessage;
  final ValueChanged<MessageRow>? onReply;
  final ValueChanged<MessageRow>? onDelete;
  final ValueChanged<MessageRow>? onForward;
  final ValueChanged<MessageRow>? onTogglePin;
  final bool showInlineActions;
  final VoidCallback? onToggleActions;
  final bool isPinned;

  const ConversationMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.peerId,
    required this.isGroup,
    required this.senderLabel,
    required this.downloadProgress,
    required this.showStatus,
    this.repliedMessage,
    this.onReply,
    this.onDelete,
    this.onForward,
    this.onTogglePin,
    this.showInlineActions = false,
    this.onToggleActions,
    this.isPinned = false,
  });

  @override
  ConsumerState<ConversationMessageBubble> createState() =>
      _ConversationMessageBubbleState();
}

class _ConversationMessageBubbleState
    extends ConsumerState<ConversationMessageBubble> {
  bool _isHovered = false;

  bool get _supportsHover {
    if (kIsWeb) return true;
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    if (widget.message.type == 'system') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              widget.message.textBody ?? '',
              style: TextStyle(color: palette.textMuted, fontSize: 12),
            ),
          ),
        ),
      );
    }

    final attachmentsAsync = ref.watch(
      messageAttachmentsProvider(widget.message.id),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: attachmentsAsync.when(
        data: (attachments) {
          final attachment = attachments.isEmpty ? null : attachments.first;
          final actionsVisible = _supportsHover
              ? _isHovered
              : widget.showInlineActions;
          final alignment = widget.isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start;
          final textAlign = widget.isMe ? TextAlign.right : TextAlign.left;
          final showCopy =
              (widget.message.textBody?.trim().isNotEmpty ?? false);

          return MouseRegion(
            onEnter: _supportsHover
                ? (_) => setState(() => _isHovered = true)
                : null,
            onExit: _supportsHover
                ? (_) => setState(() => _isHovered = false)
                : null,
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                if (widget.isGroup && !widget.isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 5),
                    child: Text(
                      widget.senderLabel,
                      style: TextStyle(
                        color: palette.groupAccent.withValues(alpha: 0.9),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxBubbleWidth = (constraints.maxWidth - 40).clamp(
                      140.0,
                      320.0,
                    );

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (widget.isMe)
                          MessageMenuSlot(
                            visible: actionsVisible,
                            message: widget.message,
                            isPinned: widget.isPinned,
                            showCopy: showCopy,
                            onReply: widget.onReply,
                            onForward: widget.onForward,
                            onTogglePin: widget.onTogglePin,
                            onDelete: widget.onDelete,
                          ),
                        GestureDetector(
                          onTap: _supportsHover ? null : widget.onToggleActions,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: maxBubbleWidth,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: widget.isMe
                                    ? [
                                        palette.brand.withValues(alpha: 0.38),
                                        palette.brand.withValues(alpha: 0.22),
                                      ]
                                    : [
                                        palette.surfaceRaised.withValues(
                                          alpha: 0.86,
                                        ),
                                        palette.surface.withValues(alpha: 0.96),
                                      ],
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(
                                  widget.isMe ? 18 : 8,
                                ),
                                bottomRight: Radius.circular(
                                  widget.isMe ? 8 : 18,
                                ),
                              ),
                              border: Border.all(
                                color: palette.border.withValues(
                                  alpha: widget.isMe ? 0.16 : 0.14,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.16),
                                  blurRadius: 14,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: attachment != null
                                ? AttachmentMessageContent(
                                    attachment: attachment,
                                    peerId: widget.peerId,
                                    isMe: widget.isMe,
                                    downloadProgress: widget.downloadProgress,
                                    repliedMessage: widget.repliedMessage,
                                  )
                                : TextLikeMessageContent(
                                    message: widget.message,
                                    textAlign: textAlign,
                                    repliedMessage: widget.repliedMessage,
                                  ),
                          ),
                        ),
                        if (!widget.isMe)
                          MessageMenuSlot(
                            visible: actionsVisible,
                            message: widget.message,
                            isPinned: widget.isPinned,
                            showCopy: showCopy,
                            onReply: widget.onReply,
                            onForward: widget.onForward,
                            onTogglePin: widget.onTogglePin,
                            onDelete: widget.onDelete,
                          ),
                      ],
                    );
                  },
                ),
                if (widget.showStatus) ...[
                  const SizedBox(height: 5),
                  Text(
                    _statusLabel(
                      message: widget.message,
                      attachment: attachment,
                      isMe: widget.isMe,
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: palette.textMuted.withValues(alpha: 0.62),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (error, stackTrace) =>
            Text('$error', style: TextStyle(color: palette.danger)),
      ),
    );
  }

  static String _statusLabel({
    required MessageRow message,
    required AttachmentRow? attachment,
    required bool isMe,
  }) {
    if (attachment != null) {
      switch (attachment.transferState) {
        case 'offered':
          return 'Available to download';
        case 'awaiting_accept':
          return isMe ? 'Waiting for download' : 'Pending';
        case 'downloading':
          return 'Downloading';
        case 'transferring':
          return isMe ? 'Sending file' : 'Receiving file';
        case 'completed':
          return 'Ready';
        case 'cancelled':
          return 'Cancelled';
        case 'failed':
          return 'Failed';
      }
    }

    if (message.type == 'call_summary') {
      return 'Call summary';
    }

    switch (message.status) {
      case 'pending':
        return 'Sending';
      case 'sent':
        return 'Sent';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      default:
        return message.status;
    }
  }
}
