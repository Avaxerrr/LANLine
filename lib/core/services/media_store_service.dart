import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Platform channel wrapper for Android MediaStore operations.
/// On non-Android platforms, operations are no-ops / return nulls.
class MediaStoreService {
  static const _channel = MethodChannel('com.lanline.lanline/mediastore');

  /// Saves a temporary file to public Downloads/LANLine via MediaStore.
  /// Returns the content URI on success, null on failure.
  /// The source temp file is deleted after successful copy.
  static Future<String?> saveToDownloads(String sourcePath, String fileName, {String? mimeType}) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<String>('saveToDownloads', {
        'sourcePath': sourcePath,
        'fileName': fileName,
        'mimeType': mimeType ?? _getMimeType(fileName),
      });
      return result;
    } catch (e) {
      return null;
    }
  }

  /// Deletes a file from Downloads/LANLine via MediaStore.
  static Future<bool> deleteFromDownloads(String fileName) async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('deleteFromDownloads', {
        'fileName': fileName,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Gets the public Downloads/LANLine directory path (for display only).
  static Future<String?> getDownloadsPath() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getDownloadsPath');
    } catch (e) {
      return null;
    }
  }

  static String _getMimeType(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    const mimeMap = {
      '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
      '.gif': 'image/gif', '.webp': 'image/webp', '.bmp': 'image/bmp',
      '.mp4': 'video/mp4', '.mkv': 'video/x-matroska', '.avi': 'video/x-msvideo',
      '.mov': 'video/quicktime', '.webm': 'video/webm',
      '.mp3': 'audio/mpeg', '.m4a': 'audio/mp4', '.wav': 'audio/wav',
      '.ogg': 'audio/ogg', '.flac': 'audio/flac', '.aac': 'audio/aac',
      '.pdf': 'application/pdf', '.doc': 'application/msword',
      '.txt': 'text/plain', '.csv': 'text/csv', '.json': 'application/json',
      '.zip': 'application/zip', '.rar': 'application/x-rar-compressed',
      '.apk': 'application/vnd.android.package-archive',
    };
    return mimeMap[ext] ?? 'application/octet-stream';
  }
}
