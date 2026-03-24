import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/download_history_provider.dart';
import '../../../core/theme/app_theme.dart';

class DownloadHistoryScreen extends ConsumerWidget {
  const DownloadHistoryScreen({super.key});

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  IconData _getFileIcon(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
      case '.bmp':
        return Icons.image_outlined;
      case '.mp4':
      case '.mkv':
      case '.avi':
      case '.mov':
      case '.webm':
        return Icons.video_file_outlined;
      case '.mp3':
      case '.m4a':
      case '.wav':
      case '.flac':
      case '.ogg':
      case '.aac':
        return Icons.audio_file_outlined;
      case '.pdf':
        return Icons.picture_as_pdf_outlined;
      case '.doc':
      case '.docx':
      case '.txt':
      case '.csv':
        return Icons.description_outlined;
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return Icons.folder_zip_outlined;
      case '.apk':
        return Icons.android_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color _getFileColor(String fileName) {
    // File accents stay semantic, but use theme-aligned defaults where possible.
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
      case '.bmp':
        return Colors.pinkAccent;
      case '.mp4':
      case '.mkv':
      case '.avi':
      case '.mov':
      case '.webm':
        return Colors.purpleAccent;
      case '.mp3':
      case '.m4a':
      case '.wav':
      case '.flac':
      case '.ogg':
      case '.aac':
        return Colors.orangeAccent;
      case '.pdf':
        return Colors.redAccent;
      case '.doc':
      case '.docx':
      case '.txt':
      case '.csv':
        return Colors.blueAccent;
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  void _openFile(String path) {
    final ext = p.extension(path).toLowerCase();
    const mimeMap = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.bmp': 'image/bmp',
      '.mp4': 'video/mp4',
      '.mkv': 'video/x-matroska',
      '.avi': 'video/x-msvideo',
      '.mov': 'video/quicktime',
      '.webm': 'video/webm',
      '.mp3': 'audio/mpeg',
      '.m4a': 'audio/mp4',
      '.wav': 'audio/wav',
      '.ogg': 'audio/ogg',
      '.flac': 'audio/flac',
      '.aac': 'audio/aac',
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.txt': 'text/plain',
      '.csv': 'text/csv',
      '.json': 'application/json',
      '.zip': 'application/zip',
      '.apk': 'application/vnd.android.package-archive',
    };
    OpenFilex.open(path, type: mimeMap[ext]);
  }

  Future<void> _shareFile(String path) async {
    final file = XFile(path);
    await SharePlus.instance.share(ShareParams(files: [file]));
  }

  Future<void> _openFolder(String path) async {
    final dir = p.dirname(path);
    if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dir]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir]);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(downloadHistoryProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Downloads',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              onPressed: () => _showClearAllDialog(context, ref),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (history.isNotEmpty) ...[
            _SummaryCard(historyCount: history.length),
            const SizedBox(height: 18),
          ],
          if (history.isEmpty)
            _EmptyDownloadsCard(platformMessage: _emptyPlatformMessage())
          else
            Column(
              children: [
                for (var index = 0; index < history.length; index++)
                  _DownloadHistoryItem(
                    record: history[index],
                    fileSizeLabel: _formatFileSize(history[index].fileSize),
                    timeLabel: _formatDate(history[index].downloadedAt),
                    icon: _getFileIcon(history[index].fileName),
                    accent: _getFileColor(history[index].fileName),
                    onOpen: history[index].fileExists
                        ? () => _openFile(history[index].filePath)
                        : null,
                    onShareOrReveal: history[index].fileExists
                        ? () => Platform.isAndroid
                              ? _shareFile(history[index].filePath)
                              : _openFolder(history[index].filePath)
                        : null,
                    onDelete: () => ref
                        .read(downloadHistoryProvider.notifier)
                        .deleteRecord(index),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _emptyPlatformMessage() {
    if (Platform.isAndroid) {
      return 'Files you receive will be saved to Downloads/LANLine.';
    }
    return 'Files you receive in chat will appear here.';
  }

  Future<void> _showClearAllDialog(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Clear all downloads?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This removes downloaded files from the device and clears the history list.',
          style: TextStyle(color: Colors.white60),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(downloadHistoryProvider.notifier).clearAll();
              Navigator.pop(ctx);
            },
            child: const Text(
              'Delete all',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int historyCount;

  const _SummaryCard({required this.historyCount});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: palette.surfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: palette.brand.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.download_done_outlined, color: palette.brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Download history',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  historyCount == 0
                      ? 'No files received yet'
                      : '$historyCount saved file${historyCount == 1 ? '' : 's'}',
                  style: TextStyle(color: palette.textMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: palette.surfaceMuted.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              historyCount == 0 ? '0 files' : '$historyCount items',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDownloadsCard extends StatelessWidget {
  final String platformMessage;

  const _EmptyDownloadsCard({required this.platformMessage});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: palette.surfaceGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.brand.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.file_download_done_outlined,
              size: 32,
              color: palette.brand,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No downloads yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            platformMessage,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _DownloadHistoryItem extends StatelessWidget {
  final DownloadRecord record;
  final String fileSizeLabel;
  final String timeLabel;
  final IconData icon;
  final Color accent;
  final VoidCallback? onOpen;
  final VoidCallback? onShareOrReveal;
  final VoidCallback onDelete;

  const _DownloadHistoryItem({
    required this.record,
    required this.fileSizeLabel,
    required this.timeLabel,
    required this.icon,
    required this.accent,
    required this.onOpen,
    required this.onShareOrReveal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    final exists = record.fileExists;
    final conversationLabel = record.roomName.trim().isEmpty
        ? 'Conversation'
        : record.roomName.trim();

    return Dismissible(
      key: Key('${record.filePath}-${record.downloadedAt.toIso8601String()}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: context.appPalette.danger,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: palette.surfaceGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: exists
                                ? Colors.white
                                : context.appPalette.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            decoration: exists
                                ? null
                                : TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaPill(
                              icon: Icons.sd_storage_outlined,
                              label: fileSizeLabel,
                            ),
                            _MetaPill(
                              icon: Icons.person_outline,
                              label: record.senderName,
                            ),
                            _MetaPill(
                              icon: Icons.chat_bubble_outline,
                              label: conversationLabel,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exists ? timeLabel : 'File missing from disk',
                      style: TextStyle(
                        color: exists
                            ? context.appPalette.textMuted
                            : context.appPalette.danger,
                      ),
                    ),
                  ),
                  if (exists) ...[
                    IconButton(
                      tooltip: 'Open',
                      onPressed: onOpen,
                      icon: Icon(Icons.open_in_new, color: palette.brand),
                    ),
                    IconButton(
                      tooltip: Platform.isAndroid ? 'Share' : 'Open folder',
                      onPressed: onShareOrReveal,
                      icon: Icon(
                        Platform.isAndroid
                            ? Icons.share_outlined
                            : Icons.folder_open,
                        color: context.appPalette.warning,
                      ),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline,
                      color: context.appPalette.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = context.appPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surfaceMuted.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.textMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: palette.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
