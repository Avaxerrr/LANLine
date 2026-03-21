import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/download_history_provider.dart';

class DownloadHistoryScreen extends ConsumerWidget {
  const DownloadHistoryScreen({super.key});

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      case '.jpg': case '.jpeg': case '.png': case '.gif': case '.webp': case '.bmp':
        return Icons.image;
      case '.mp4': case '.mkv': case '.avi': case '.mov': case '.webm':
        return Icons.video_file;
      case '.mp3': case '.m4a': case '.wav': case '.flac': case '.ogg': case '.aac':
        return Icons.audio_file;
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc': case '.docx': case '.txt': case '.csv':
        return Icons.description;
      case '.zip': case '.rar': case '.7z': case '.tar': case '.gz':
        return Icons.folder_zip;
      case '.apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg': case '.jpeg': case '.png': case '.gif': case '.webp': case '.bmp':
        return Colors.pinkAccent;
      case '.mp4': case '.mkv': case '.avi': case '.mov': case '.webm':
        return Colors.purpleAccent;
      case '.mp3': case '.m4a': case '.wav': case '.flac': case '.ogg': case '.aac':
        return Colors.orangeAccent;
      case '.pdf':
        return Colors.redAccent;
      case '.doc': case '.docx': case '.txt': case '.csv':
        return Colors.blueAccent;
      case '.zip': case '.rar': case '.7z': case '.tar': case '.gz':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  void _openFile(String path) {
    final ext = p.extension(path).toLowerCase();
    const mimeMap = {
      '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
      '.gif': 'image/gif', '.webp': 'image/webp', '.bmp': 'image/bmp',
      '.mp4': 'video/mp4', '.mkv': 'video/x-matroska', '.avi': 'video/x-msvideo',
      '.mov': 'video/quicktime', '.webm': 'video/webm',
      '.mp3': 'audio/mpeg', '.m4a': 'audio/mp4', '.wav': 'audio/wav',
      '.ogg': 'audio/ogg', '.flac': 'audio/flac', '.aac': 'audio/aac',
      '.pdf': 'application/pdf', '.doc': 'application/msword',
      '.txt': 'text/plain', '.csv': 'text/csv', '.json': 'application/json',
      '.zip': 'application/zip', '.apk': 'application/vnd.android.package-archive',
    };
    OpenFilex.open(path, type: mimeMap[ext]);
  }

  void _shareFile(String path) async {
    final file = XFile(path);
    await SharePlus.instance.share(ShareParams(files: [file]));
  }

  void _openFolder(String path) async {
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
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Downloads', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (history.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${history.length}', style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF252525),
        elevation: 4,
        actions: [
          if (history.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xFF333333),
              onSelected: (value) {
                if (value == 'clear_all') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF333333),
                      title: const Text('Clear All Downloads?', style: TextStyle(color: Colors.white)),
                      content: const Text(
                        'This will delete all downloaded files and clear the history.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            ref.read(downloadHistoryProvider.notifier).clearAll();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Delete All', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'clear_all', child: Text('Clear All', style: TextStyle(color: Colors.redAccent))),
              ],
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_done, size: 64, color: Colors.grey.shade700),
                  const SizedBox(height: 16),
                  const Text('No downloads yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    Platform.isAndroid
                        ? 'Files you receive will be saved to Downloads/LANLine'
                        : 'Files you receive in chat will appear here',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final record = history[index];
                final exists = record.fileExists;

                return Dismissible(
                  key: Key(record.filePath + record.downloadedAt.toIso8601String()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    ref.read(downloadHistoryProvider.notifier).deleteRecord(index);
                  },
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getFileColor(record.fileName).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getFileIcon(record.fileName),
                        color: _getFileColor(record.fileName),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      record.fileName,
                      style: TextStyle(
                        color: exists ? Colors.white : Colors.grey,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: exists ? null : TextDecoration.lineThrough,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatFileSize(record.fileSize)} • From ${record.senderName}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          '${record.roomName} • ${_formatDate(record.downloadedAt)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        ),
                      ],
                    ),
                    trailing: exists
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new, color: Colors.blueAccent, size: 20),
                                tooltip: 'Open',
                                onPressed: () => _openFile(record.filePath),
                              ),
                              if (Platform.isAndroid)
                                IconButton(
                                  icon: const Icon(Icons.share, color: Colors.orangeAccent, size: 20),
                                  tooltip: 'Share',
                                  onPressed: () => _shareFile(record.filePath),
                                )
                              else
                                IconButton(
                                  icon: const Icon(Icons.folder_open, color: Colors.orangeAccent, size: 20),
                                  tooltip: 'Open Folder',
                                  onPressed: () => _openFolder(record.filePath),
                                ),
                            ],
                          )
                        : const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                  ),
                );
              },
            ),
    );
  }
}
