import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/models/chat_message.dart';

/// Renders a single chat message bubble with sender label, timestamp,
/// read receipt, file preview, and action buttons.
class ChatMessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final int index;

  /// Full message list — needed for grouping (prev/next sender check).
  final List<ChatMessage> messages;

  /// Indices of messages whose timestamps are expanded by tap.
  final Set<int> expandedTimestamps;

  /// Download progress map: offerId -> [received, total].
  final Map<String, List<int>> downloadProgress;

  /// Audio player for playing voice memos and audio files.
  final AudioPlayer audioPlayer;

  /// Callbacks for file transfer actions.
  final void Function(String offerId) onAcceptFile;
  final void Function(String offerId) onCancelFile;

  /// Callback when a timestamp is toggled (tapped).
  final void Function(int index) onToggleTimestamp;

  /// Callback to show a top snackbar message.
  final void Function(String message) onShowSnackBar;

  const ChatMessageBubble({
    super.key,
    required this.msg,
    required this.index,
    required this.messages,
    required this.expandedTimestamps,
    required this.downloadProgress,
    required this.audioPlayer,
    required this.onAcceptFile,
    required this.onCancelFile,
    required this.onToggleTimestamp,
    required this.onShowSnackBar,
  });

  @override
  Widget build(BuildContext context) {
    // Message grouping: hide sender if same sender as previous message
    final bool showSender;
    if (msg.isMe) {
      showSender = false;
    } else if (index == 0) {
      showSender = true;
    } else {
      final prev = messages[index - 1];
      showSender = prev.sender != msg.sender || prev.isMe != msg.isMe;
    }

    // Reduce spacing for grouped messages
    final bottomPadding =
        (!msg.isMe &&
            index < messages.length - 1 &&
            messages[index + 1].sender == msg.sender &&
            !messages[index + 1].isMe)
        ? 4.0
        : 14.0;

    // Only show timestamp on the last message, or when explicitly tapped
    final isLastMessage = index == messages.length - 1;
    final showTimestamp = isLastMessage || expandedTimestamps.contains(index);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: msg.isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                msg.sender,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          GestureDetector(
            onLongPress: () => _showMessageOptions(context, msg),
            onTap: isLastMessage ? null : () => onToggleTimestamp(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: msg.isMe ? Colors.blueAccent : const Color(0xFF333333),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(msg.isMe ? 20 : 0),
                  bottomRight: Radius.circular(msg.isMe ? 0 : 20),
                ),
              ),
              child: _buildMessageContent(msg),
            ),
          ),
          // Timestamp + read receipt — animated slide
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: showTimestamp
                ? Padding(
                    padding: const EdgeInsets.only(top: 3, left: 12, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimestamp(msg.timestamp),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                        if (msg.isMe && msg.id != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all,
                            size: 14,
                            color: msg.isAcked
                                ? Colors.blueAccent
                                : Colors.grey,
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Message content ──────────────────────────────────────────

  Widget _buildMessageContent(ChatMessage msg) {
    if (msg.filePath != null || msg.offerId != null) {
      return _buildFileBubble(msg);
    }
    if (msg.text.contains('.m4a') && msg.text.contains('Saved to: ')) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 36,
            ),
            onPressed: () {
              final pathMatch = msg.text.split('Saved to: ');
              if (pathMatch.length == 2) {
                audioPlayer.play(DeviceFileSource(pathMatch[1].trim()));
              }
            },
          ),
          const Expanded(
            child: Text(
              "🎵 Voice Memo Received",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      );
    }
    if (msg.text.contains('.m4a') && msg.text.startsWith('🎤 Sent Voi')) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.audiotrack, color: Colors.white, size: 30),
          SizedBox(width: 8),
          Text("🎵 Audio message sent", style: TextStyle(color: Colors.white)),
        ],
      );
    }

    // Emoji-only: render large
    if (isEmojiOnly(msg.text)) {
      return Text(msg.text, style: const TextStyle(fontSize: 42));
    }

    // Linkified text with clickable URLs
    return Linkify(
      text: msg.text,
      style: const TextStyle(color: Colors.white, fontSize: 15),
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
    );
  }

  // ── File bubble ──────────────────────────────────────────────

  Widget _buildFileBubble(ChatMessage msg) {
    final fileName =
        msg.fileName ??
        (msg.filePath != null ? p.basename(msg.filePath!) : 'Unknown file');
    final isCompleted = msg.filePath != null;
    final isOffer = msg.offerId != null && !isCompleted;
    final isAudio =
        msg.filePath != null &&
        (msg.filePath!.endsWith('.m4a') ||
            msg.filePath!.endsWith('.mp3') ||
            msg.filePath!.endsWith('.wav'));
    final isImage = isImageFile(msg.filePath);
    final icon = isAudio
        ? Icons.audiotrack
        : (isImage ? Icons.image : Icons.insert_drive_file);

    // Show inline image preview for completed image files
    if (isCompleted && isImage && !msg.isMe) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: Image.file(
                File(msg.filePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(fileName, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _fileActionButton(
                Icons.open_in_new,
                'Open',
                () => _openFile(msg.filePath!),
              ),
              const SizedBox(width: 8),
              if (Platform.isAndroid)
                _fileActionButton(
                  Icons.share,
                  'Share',
                  () => _shareFile(msg.filePath!),
                )
              else
                _fileActionButton(
                  Icons.folder_open,
                  'Folder',
                  () => _openFolder(msg.filePath!),
                ),
            ],
          ),
        ],
      );
    }

    // Sender's own image preview
    if (isCompleted && isImage && msg.isMe) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: Image.file(
                File(msg.filePath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(fileName, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          if (msg.offerId != null && !msg.isCancelled) ...[
            const SizedBox(height: 6),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                SizedBox(width: 6),
                Text(
                  'Downloaded',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  if (msg.fileSize != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        formatFileSize(msg.fileSize!),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),

        // Cancelled
        if (msg.isCancelled) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cancel,
                color: Colors.redAccent.withValues(alpha: 0.7),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Cancelled',
                style: TextStyle(
                  color: Colors.redAccent.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],

        // Pending offer — Download button (receiver only)
        if (isOffer && !msg.isMe && !msg.isDownloading && !msg.isCancelled) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _fileActionButton(
                Icons.download,
                'Download',
                () => onAcceptFile(msg.offerId!),
              ),
            ],
          ),
        ],

        // Downloading — progress bar + cancel
        if (msg.isDownloading && !msg.isCancelled) ...[
          const SizedBox(height: 10),
          Builder(
            builder: (_) {
              final progress = downloadProgress[msg.offerId];
              final received = progress?[0] ?? 0;
              final total = progress?[1] ?? 1;
              final pct = total > 0 ? received / total : 0.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.greenAccent,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(pct * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (msg.fileSize != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '${formatFileSize((pct * msg.fileSize!).round())} / ${formatFileSize(msg.fileSize!)}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const Spacer(),
                      InkWell(
                        onTap: () => onCancelFile(msg.offerId!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close,
                                color: Colors.redAccent,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],

        // Sender: waiting for download + cancel, or downloaded status
        if (isOffer && msg.isMe && !msg.isCancelled) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⏳ Waiting for download',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => onCancelFile(msg.offerId!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, color: Colors.redAccent, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],

        // Sender: file was downloaded by someone (isCompleted && isMe && had offer)
        if (isCompleted &&
            msg.isMe &&
            msg.offerId != null &&
            !msg.isCancelled) ...[
          const SizedBox(height: 8),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
              SizedBox(width: 6),
              Text(
                'Downloaded',
                style: TextStyle(color: Colors.greenAccent, fontSize: 12),
              ),
            ],
          ),
        ],

        // Completed file: Open/Folder/Play buttons (receiver side)
        if (isCompleted && !msg.isMe) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAudio)
                _fileActionButton(Icons.play_arrow, 'Play', () {
                  audioPlayer.play(DeviceFileSource(msg.filePath!));
                }),
              _fileActionButton(
                Icons.open_in_new,
                'Open',
                () => _openFile(msg.filePath!),
              ),
              const SizedBox(width: 8),
              if (Platform.isAndroid)
                _fileActionButton(
                  Icons.share,
                  'Share',
                  () => _shareFile(msg.filePath!),
                )
              else
                _fileActionButton(
                  Icons.folder_open,
                  'Folder',
                  () => _openFolder(msg.filePath!),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  Widget _fileActionButton(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(BuildContext context, ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (msg.text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.blueAccent),
                  title: const Text(
                    'Copy Text',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    Navigator.pop(ctx);
                    onShowSnackBar('Copied to clipboard');
                  },
                ),
              if (msg.filePath != null)
                ListTile(
                  leading: const Icon(
                    Icons.open_in_new,
                    color: Colors.orangeAccent,
                  ),
                  title: const Text(
                    'Open File',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFile(msg.filePath!);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  static void _openFile(String path) async {
    final mimeType = _getMimeType(path);
    await OpenFilex.open(path, type: mimeType);
  }

  static String? _getMimeType(String path) {
    final ext = p.extension(path).toLowerCase();
    const mimeMap = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.bmp': 'image/bmp',
      '.svg': 'image/svg+xml',
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
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain',
      '.csv': 'text/csv',
      '.json': 'application/json',
      '.zip': 'application/zip',
      '.rar': 'application/x-rar-compressed',
      '.7z': 'application/x-7z-compressed',
      '.tar': 'application/x-tar',
      '.gz': 'application/gzip',
      '.apk': 'application/vnd.android.package-archive',
    };
    return mimeMap[ext];
  }

  static void _openFolder(String path) async {
    final dir = p.dirname(path);
    if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dir]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir]);
    }
  }

  static void _shareFile(String path) async {
    final file = XFile(path);
    await SharePlus.instance.share(ShareParams(files: [file]));
  }
}
