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
import '../../../../core/providers/v2_data_providers.dart';

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
    if (widget.message.type == 'system') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1B1B),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              widget.message.textBody ?? '',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
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
          final bubbleColor = widget.isMe
              ? Colors.blueAccent.withValues(alpha: 0.22)
              : const Color(0xFF1F1F1F);
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
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      widget.senderLabel,
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
                              color: bubbleColor,
                              borderRadius: BorderRadius.circular(18),
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
                  const SizedBox(height: 4),
                  Text(
                    _statusLabel(
                      message: widget.message,
                      attachment: attachment,
                      isMe: widget.isMe,
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (error, stackTrace) =>
            Text('$error', style: const TextStyle(color: Colors.redAccent)),
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
    return PopupMenuButton<_MessageMenuAction>(
      tooltip: 'Message actions',
      padding: EdgeInsets.zero,
      color: const Color(0xFF1E1E1E),
      offset: const Offset(0, 8),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Center(child: Icon(Icons.more_horiz, size: 16)),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem<_MessageMenuAction>(
          value: _MessageMenuAction.reply,
          child: _OverflowMenuLabel(
            icon: Icons.reply_outlined,
            label: 'Reply',
            color: Colors.greenAccent,
          ),
        ),
        if (showCopy)
          const PopupMenuItem<_MessageMenuAction>(
            value: _MessageMenuAction.copy,
            child: _OverflowMenuLabel(
              icon: Icons.copy_all_outlined,
              label: 'Copy text',
              color: Colors.blueAccent,
            ),
          ),
        if (showCopy)
          const PopupMenuItem<_MessageMenuAction>(
            value: _MessageMenuAction.forward,
            child: _OverflowMenuLabel(
              icon: Icons.forward_outlined,
              label: 'Forward',
              color: Colors.amber,
            ),
          ),
        PopupMenuItem<_MessageMenuAction>(
          value: _MessageMenuAction.pin,
          child: _OverflowMenuLabel(
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: isPinned ? 'Unpin' : 'Pin',
            color: Colors.amber,
          ),
        ),
        const PopupMenuItem<_MessageMenuAction>(
          value: _MessageMenuAction.delete,
          child: _OverflowMenuLabel(
            icon: Icons.delete_outline,
            label: 'Delete from this device',
            color: Colors.redAccent,
          ),
        ),
      ],
      onSelected: (action) =>
          _handleOverflowAction(context, action: action, message: message),
    );
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
            backgroundColor: const Color(0xFF1E1E1E),
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
                  backgroundColor: Colors.redAccent,
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
              Icon(icon, color: Colors.greenAccent, size: 18),
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
            style: const TextStyle(fontSize: 42, height: 1.0),
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
            fontSize: 15,
            height: 1.35,
          ),
          linkStyle: const TextStyle(
            color: Colors.lightBlueAccent,
            decoration: TextDecoration.underline,
            fontSize: 15,
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
    final alignment = textAlign == TextAlign.right
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: Colors.blueAccent.withValues(alpha: 0.85),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Text(
            'Replying to',
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _previewText(message),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
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
    final progress = downloadProgress[attachment.id];
    final progressValue = progress == null || progress[1] == 0
        ? null
        : progress[0] / progress[1];
    final hasImagePreview =
        attachment.kind == 'image' &&
        attachment.localPath != null &&
        File(attachment.localPath!).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (repliedMessage != null) ...[
          ReplyPreview(message: repliedMessage!, textAlign: TextAlign.left),
          const SizedBox(height: 8),
        ],
        if (hasImagePreview) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: Image.file(
                File(attachment.localPath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white.withValues(alpha: 0.06),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        'Could not preview image',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _iconForKind(attachment.kind),
                color: Colors.white,
                size: 24,
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
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatFileSize(attachment.fileSize),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (attachment.transferState == 'downloading' &&
            progressValue != null) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.greenAccent,
              ),
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
      return const [
        Text(
          'Direct-chat only for file transfers right now.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ];
    }

    if (!isMe && attachment.transferState == 'offered') {
      return [
        _actionButton(
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
          icon: Icons.open_in_new,
          label: 'Open',
          onTap: () => OpenFilex.open(
            attachment.localPath!,
            type: _guessMimeType(attachment.localPath!),
          ),
        ),
        if (Platform.isAndroid)
          _actionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: () => SharePlus.instance.share(
              ShareParams(files: [XFile(attachment.localPath!)]),
            ),
          )
        else
          _actionButton(
            icon: Icons.folder_open,
            label: 'Folder',
            onTap: () => _openFolder(attachment.localPath!),
          ),
      ];
    }

    if (attachment.transferState == 'cancelled') {
      return const [
        Text(
          'Transfer cancelled',
          style: TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ];
    }

    return const [];
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
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
