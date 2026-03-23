import 'package:characters/characters.dart';
import 'package:path/path.dart' as p;

bool isEmojiOnly(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;

  final clusters = trimmed.characters.toList();
  if (clusters.length > 3) return false;

  return clusters.every(_looksLikeEmojiCluster);
}

bool _looksLikeEmojiCluster(String cluster) {
  final containsEmojiRune = cluster.runes.any(_isEmojiRune);
  final containsAsciiWordChar = cluster.contains(RegExp(r'[A-Za-z0-9]'));
  return containsEmojiRune && !containsAsciiWordChar;
}

bool _isEmojiRune(int rune) {
  return (rune >= 0x1F300 && rune <= 0x1FAFF) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      rune == 0x200D ||
      rune == 0xFE0F;
}

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
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
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
