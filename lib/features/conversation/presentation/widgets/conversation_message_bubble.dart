import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/models/chat_message.dart';
import '../../../../core/providers/data_providers.dart';
import '../../../../core/theme/app_theme.dart';
import 'media_viewer.dart';

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
                          _MessageMenuSlot(
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
                          _MessageMenuSlot(
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

enum _MessageMenuAction { reply, copy, forward, pin, delete }

class _MessageMenuSlot extends StatelessWidget {
  final bool visible;
  final MessageRow message;
  final bool isPinned;
  final bool showCopy;
  final ValueChanged<MessageRow>? onReply;
  final ValueChanged<MessageRow>? onForward;
  final ValueChanged<MessageRow>? onTogglePin;
  final ValueChanged<MessageRow>? onDelete;

  const _MessageMenuSlot({
    required this.visible,
    required this.message,
    required this.isPinned,
    required this.showCopy,
    required this.onReply,
    required this.onForward,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 120),
        child: IgnorePointer(
          ignoring: !visible,
          child: Align(
            child: _MessageMenuButton(
              message: message,
              isPinned: isPinned,
              showCopy: showCopy,
              onReply: onReply,
              onForward: onForward,
              onTogglePin: onTogglePin,
              onDelete: onDelete,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageMenuButton extends StatelessWidget {
  final MessageRow message;
  final bool isPinned;
  final bool showCopy;
  final ValueChanged<MessageRow>? onReply;
  final ValueChanged<MessageRow>? onForward;
  final ValueChanged<MessageRow>? onTogglePin;
  final ValueChanged<MessageRow>? onDelete;

  const _MessageMenuButton({
    required this.message,
    required this.isPinned,
    required this.showCopy,
    required this.onReply,
    required this.onForward,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Tooltip(
      message: 'Message actions',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _showMenu(context, details.globalPosition),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: palette.menuSurface.withValues(alpha: 0.96),
              shape: BoxShape.circle,
              border: Border.all(color: palette.border.withValues(alpha: 0.16)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Center(child: Icon(Icons.more_horiz, size: 16)),
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, Offset globalPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final action = await showMenu<_MessageMenuAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx - 14,
        globalPosition.dy + 14,
        overlay.size.width - globalPosition.dx - 14,
        overlay.size.height - globalPosition.dy - 14,
      ),
      items: [
        PopupMenuItem<_MessageMenuAction>(
          value: _MessageMenuAction.reply,
          child: _OverflowMenuLabel(
            icon: Icons.reply_outlined,
            label: 'Reply',
            color: context.appPalette.positive,
          ),
        ),
        if (showCopy)
          PopupMenuItem<_MessageMenuAction>(
            value: _MessageMenuAction.copy,
            child: _OverflowMenuLabel(
              icon: Icons.copy_all_outlined,
              label: 'Copy text',
              color: context.appPalette.brand,
            ),
          ),
        if (showCopy)
          PopupMenuItem<_MessageMenuAction>(
            value: _MessageMenuAction.forward,
            child: _OverflowMenuLabel(
              icon: Icons.forward_outlined,
              label: 'Forward',
              color: context.appPalette.groupAccent,
            ),
          ),
        PopupMenuItem<_MessageMenuAction>(
          value: _MessageMenuAction.pin,
          child: _OverflowMenuLabel(
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: isPinned ? 'Unpin' : 'Pin',
            color: context.appPalette.groupAccent,
          ),
        ),
        PopupMenuItem<_MessageMenuAction>(
          value: _MessageMenuAction.delete,
          child: _OverflowMenuLabel(
            icon: Icons.delete_outline,
            label: 'Delete from this device',
            color: context.appPalette.danger,
          ),
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    await _handleOverflowAction(context, action: action, message: message);
  }

  Future<void> _handleOverflowAction(
    BuildContext context, {
    required _MessageMenuAction action,
    required MessageRow message,
  }) async {
    switch (action) {
      case _MessageMenuAction.reply:
        onReply?.call(message);
        return;
      case _MessageMenuAction.copy:
        final text = message.textBody?.trim() ?? '';
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
        return;
      case _MessageMenuAction.forward:
        onForward?.call(message);
        return;
      case _MessageMenuAction.pin:
        onTogglePin?.call(message);
        return;
      case _MessageMenuAction.delete:
        final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete message'),
            content: const Text(
              'This only removes the message from this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: FilledButton.styleFrom(
                  backgroundColor: context.appPalette.danger,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (shouldDelete == true) {
          onDelete?.call(message);
        }
        return;
    }
  }
}

class _OverflowMenuLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _OverflowMenuLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label),
      ],
    );
  }
}

class TextLikeMessageContent extends StatelessWidget {
  final MessageRow message;
  final TextAlign textAlign;
  final MessageRow? repliedMessage;

  const TextLikeMessageContent({
    super.key,
    required this.message,
    required this.textAlign,
    this.repliedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final contentAlignment = textAlign == TextAlign.right
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    if (message.type == 'call_summary') {
      final metadata = message.metadataJson == null
          ? const <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(message.metadataJson!) as Map);
      final icon = metadata['callType'] == 'video'
          ? Icons.videocam
          : Icons.call;

      return Column(
        crossAxisAlignment: contentAlignment,
        children: [
          if (repliedMessage != null) ...[
            ReplyPreview(message: repliedMessage!, textAlign: textAlign),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: palette.positive, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.textBody ?? 'Call',
                  textAlign: textAlign,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final text = message.textBody ?? '';
    if (isEmojiOnly(text)) {
      return Column(
        crossAxisAlignment: contentAlignment,
        children: [
          if (repliedMessage != null) ...[
            ReplyPreview(message: repliedMessage!, textAlign: textAlign),
            const SizedBox(height: 8),
          ],
          Text(
            text,
            textAlign: textAlign,
            style: const TextStyle(fontSize: 44, height: 1.0),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: contentAlignment,
      children: [
        if (repliedMessage != null) ...[
          ReplyPreview(message: repliedMessage!, textAlign: textAlign),
          const SizedBox(height: 8),
        ],
        Linkify(
          text: text,
          textAlign: textAlign,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            height: 1.45,
          ),
          linkStyle: TextStyle(
            color: palette.brand,
            decoration: TextDecoration.underline,
            fontSize: 15.5,
          ),
          onOpen: (link) async {
            final uri = Uri.tryParse(link.url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ],
    );
  }
}

class ReplyPreview extends StatelessWidget {
  final MessageRow message;
  final TextAlign textAlign;

  const ReplyPreview({
    super.key,
    required this.message,
    required this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final alignment = textAlign == TextAlign.right
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: palette.brand.withValues(alpha: 0.85),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.subdirectory_arrow_right,
                color: palette.brand,
                size: 14,
              ),
              SizedBox(width: 4),
              Text(
                'Replying to',
                style: TextStyle(
                  color: palette.brand,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _previewText(message),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  static String _previewText(MessageRow message) {
    final text = message.textBody?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }
    switch (message.type) {
      case 'file':
        return 'Attachment';
      case 'call_summary':
        return 'Call summary';
      case 'system':
        return 'System message';
      default:
        return message.type;
    }
  }
}

class AttachmentMessageContent extends ConsumerWidget {
  final AttachmentRow attachment;
  final String? peerId;
  final bool isMe;
  final Map<String, List<int>> downloadProgress;
  final MessageRow? repliedMessage;

  const AttachmentMessageContent({
    super.key,
    required this.attachment,
    required this.peerId,
    required this.isMe,
    required this.downloadProgress,
    this.repliedMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.appPalette;
    final progress = downloadProgress[attachment.id];
    final progressValue = progress == null || progress[1] == 0
        ? null
        : progress[0] / progress[1];
    final hasLocalFile = attachment.localPath != null &&
        File(attachment.localPath!).existsSync();
    final hasImagePreview = attachment.kind == 'image' && hasLocalFile;
    final hasVideoPreview = attachment.kind == 'video' && hasLocalFile;
    final hasAudioPlayer = attachment.kind == 'audio' && hasLocalFile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (repliedMessage != null) ...[
          ReplyPreview(message: repliedMessage!, textAlign: TextAlign.left),
          const SizedBox(height: 8),
        ],
        // Image preview — tap to open full-screen viewer
        if (hasImagePreview) ...[
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImageViewerScreen(
                  filePath: attachment.localPath!,
                  fileName: attachment.fileName,
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: Image.file(
                  File(attachment.localPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    padding: const EdgeInsets.all(16),
                    color: palette.surfaceMuted.withValues(alpha: 0.82),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: palette.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Could not preview image',
                          style: TextStyle(color: palette.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            attachment.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
        ],
        // Video preview — thumbnail with play button, tap to open player
        if (hasVideoPreview) ...[
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => VideoViewerScreen(
                  filePath: attachment.localPath!,
                  fileName: attachment.fileName,
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                width: double.infinity,
                color: Colors.black,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 200,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.movie_outlined,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 64,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            attachment.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.textMuted, fontSize: 12),
          ),
        ],
        // Audio — inline player
        if (hasAudioPlayer) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceMuted.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: palette.border.withValues(alpha: 0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                InlineAudioPlayer(
                  filePath: attachment.localPath!,
                  fileName: attachment.fileName,
                  accentColor: palette.brand,
                  mutedColor: palette.textMuted,
                ),
              ],
            ),
          ),
        ],
        // Other file types — icon + name + size card
        // Text files are tappable to open in-app viewer.
        if (!hasImagePreview && !hasVideoPreview && !hasAudioPlayer)
          GestureDetector(
            onTap: hasLocalFile && isTextFile(attachment.fileName)
                ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TextViewerScreen(
                          filePath: attachment.localPath!,
                          fileName: attachment.fileName,
                        ),
                      ),
                    )
                : null,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surfaceMuted.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: palette.border.withValues(alpha: 0.14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconForKind(attachment.kind),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatFileSize(attachment.fileSize),
                          style: TextStyle(
                              color: palette.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (attachment.transferState == 'downloading' &&
            progressValue != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: palette.surface.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(palette.positive),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: _buildActions(context, ref)),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref) {
    if (peerId == null) {
      return [
        Text(
          'Direct-chat only for file transfers right now.',
          style: TextStyle(color: context.appPalette.textMuted, fontSize: 12),
        ),
      ];
    }

    if (!isMe && attachment.transferState == 'offered') {
      return [
        _actionButton(
          context: context,
          icon: Icons.download,
          label: 'Download',
          onTap: () => ref
              .read(mediaActionsProvider)
              .acceptFile(peerId: peerId!, attachmentId: attachment.id),
        ),
      ];
    }

    if ((isMe &&
            (attachment.transferState == 'awaiting_accept' ||
                attachment.transferState == 'transferring')) ||
        (!isMe && attachment.transferState == 'downloading')) {
      return [
        _actionButton(
          context: context,
          icon: Icons.close,
          label: 'Cancel',
          onTap: () => ref
              .read(mediaActionsProvider)
              .cancelFileTransfer(peerId: peerId!, attachmentId: attachment.id),
        ),
      ];
    }

    if (attachment.transferState == 'completed' &&
        attachment.localPath != null) {
      return [
        _actionButton(
          context: context,
          icon: Icons.open_in_new,
          label: 'Open',
          onTap: () => OpenFilex.open(
            attachment.localPath!,
            type: _guessMimeType(attachment.localPath!),
          ),
        ),
        if (Platform.isAndroid)
          _actionButton(
            context: context,
            icon: Icons.share,
            label: 'Share',
            onTap: () => SharePlus.instance.share(
              ShareParams(files: [XFile(attachment.localPath!)]),
            ),
          )
        else
          _actionButton(
            context: context,
            icon: Icons.folder_open,
            label: 'Folder',
            onTap: () => _openFolder(attachment.localPath!),
          ),
      ];
    }

    if (attachment.transferState == 'cancelled') {
      return [
        Text(
          'Transfer cancelled',
          style: TextStyle(color: context.appPalette.danger, fontSize: 12),
        ),
      ];
    }

    return const [];
  }

  Widget _actionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final palette = context.appPalette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForKind(String kind) {
    switch (kind) {
      case 'image':
        return Icons.image_outlined;
      case 'audio':
        return Icons.audiotrack;
      case 'video':
        return Icons.movie;
      default:
        return Icons.insert_drive_file;
    }
  }

  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String? _guessMimeType(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.svg':
        return 'image/svg+xml';
      case '.mp4':
        return 'video/mp4';
      case '.mkv':
        return 'video/x-matroska';
      case '.avi':
        return 'video/x-msvideo';
      case '.mov':
        return 'video/quicktime';
      case '.webm':
        return 'video/webm';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      case '.aac':
        return 'audio/aac';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      default:
        return null;
    }
  }

  static Future<void> _openFolder(String path) async {
    final directory = p.dirname(path);
    if (Platform.isWindows) {
      await Process.run('explorer', [directory]);
      return;
    }
    if (Platform.isMacOS) {
      await Process.run('open', [directory]);
      return;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [directory]);
    }
  }
}
