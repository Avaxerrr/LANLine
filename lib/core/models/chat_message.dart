import 'package:path/path.dart' as p;

/// Regex to detect emoji-only messages (1-3 emojis, no other text)
final _emojiOnlyRegex = RegExp(
  r'^(\p{Emoji_Presentation}|\p{Emoji}\uFE0F|[\u200D\uFE0F]){1,3}$',
  unicode: true,
);

bool isEmojiOnly(String text) => _emojiOnlyRegex.hasMatch(text.trim());

const imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};

bool isImageFile(String? path) {
  if (path == null) return false;
  final ext = p.extension(path).toLowerCase();
  return imageExtensions.contains(ext);
}

/// Format a byte count into a human-readable string (e.g. "1.5 MB").
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class ChatMessage {
  final String? id;
  final String sender;
  final String text;
  final bool isMe;
  final String? filePath;
  final String? fileName;
  final String? offerId;
  final int? fileSize;
  final DateTime timestamp;
  bool isAcked;
  bool isDownloading;
  bool isExpired;
  bool isCancelled;

  ChatMessage({
    this.id,
    required this.sender,
    required this.text,
    required this.isMe,
    this.filePath,
    this.fileName,
    this.offerId,
    this.fileSize,
    DateTime? timestamp,
    this.isAcked = false,
    this.isDownloading = false,
    this.isExpired = false,
    this.isCancelled = false,
  }) : timestamp = timestamp ?? DateTime.now();
}
