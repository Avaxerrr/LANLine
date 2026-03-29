import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/db/app_database.dart';
import '../../../../core/network/mime_utils.dart';
import '../../../../core/providers/data_providers.dart';
import '../../../../core/theme/app_theme.dart';
import 'media_viewer.dart';
import 'text_message_content.dart';

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
              .read(fileTransferActionsProvider)
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
              .read(fileTransferActionsProvider)
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
            type: guessMimeType(attachment.localPath!),
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

  static Future<void> _openFolder(String path) async {
    final directory = File(path).parent.path;
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
