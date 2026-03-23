import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../services/media_store_service.dart';

final fileTransferProvider = Provider<FileTransferManager>((ref) => FileTransferManager());

class FileTransferManager {
  static const int chunkSize = 1024 * 256;
  final Map<String, BytesBuilder> _incomingFiles = {};

  Future<List<String>> splitFileIntoChunks(
    File file,
    String sender, {
    String? offerId,
    String? attachmentId,
    String? messageId,
    String? clientGeneratedId,
    String? senderPeerId,
    String? senderDisplayName,
    String? mimeType,
    String? kind,
    int? sentAt,
  }) async {
    final filename = p.basename(file.path);
    final bytes = await file.readAsBytes();
    final totalChunks = (bytes.length / chunkSize).ceil();
    if (totalChunks == 0) return [];

    List<String> payloads = [];
    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < bytes.length) ? start + chunkSize : bytes.length;
      final chunkBytes = bytes.sublist(start, end);
      final payloadMap = {
        'type': 'file_chunk',
        'sender': sender,
        'filename': filename,
        'chunk_index': i,
        'total_chunks': totalChunks,
        'data': base64Encode(chunkBytes),
      };
      if (offerId != null) payloadMap['offer_id'] = offerId;
      if (attachmentId != null) payloadMap['attachmentId'] = attachmentId;
      if (messageId != null) payloadMap['messageId'] = messageId;
      if (clientGeneratedId != null) {
        payloadMap['clientGeneratedId'] = clientGeneratedId;
      }
      if (senderPeerId != null) payloadMap['senderPeerId'] = senderPeerId;
      if (senderDisplayName != null) {
        payloadMap['senderDisplayName'] = senderDisplayName;
      }
      if (mimeType != null) payloadMap['mimeType'] = mimeType;
      if (kind != null) payloadMap['kind'] = kind;
      if (sentAt != null) payloadMap['sentAt'] = sentAt;
      payloads.add(jsonEncode(payloadMap));
    }
    return payloads;
  }

  /// Handles an incoming chunk. Returns the saved File when transfer is complete.
  /// On Android, the file is first saved to a temp directory, then moved to
  /// public Downloads/LANLine via MediaStore.
  Future<File?> handleChunk(Map<String, dynamic> data, {String? customTestSavePath}) async {
    final filename = data['filename'] as String;
    final totalChunks = data['total_chunks'] as int;
    final chunkIndex = data['chunk_index'] as int;
    final base64Data = data['data'] as String;
    final bufferKey =
        data['attachmentId']?.toString() ??
        data['offer_id']?.toString() ??
        filename;

    _incomingFiles.putIfAbsent(bufferKey, () => BytesBuilder());
    _incomingFiles[bufferKey]!.add(base64Decode(base64Data));

    if (chunkIndex == totalChunks - 1) {
      final completeBytes = _incomingFiles.remove(bufferKey)!.takeBytes();
      return await _saveFile(filename, completeBytes, customSavePath: customTestSavePath);
    }
    return null;
  }

  void cancelFile(String filename) {
    _incomingFiles.remove(filename);
  }

  Future<File> _saveFile(String filename, List<int> bytes, {String? customSavePath}) async {
    if (customSavePath != null) {
      // Test path
      final file = File(p.join(customSavePath, filename));
      if (!await file.parent.exists()) await file.parent.create(recursive: true);
      return await file.writeAsBytes(bytes);
    }

    if (Platform.isAndroid) {
      // Step 1: Save to temp directory first
      final tempDir = await getApplicationCacheDirectory();
      final tempFile = File(p.join(tempDir.path, 'lanline_temp_$filename'));
      await tempFile.writeAsBytes(bytes);

      // Step 2: Move to public Downloads via MediaStore
      final uri = await MediaStoreService.saveToDownloads(tempFile.path, filename);
      if (uri != null) {
        // MediaStore succeeded — return a reference to the public file
        final publicPath = await MediaStoreService.getDownloadsPath();
        return File(p.join(publicPath ?? tempDir.path, filename));
      }
      // Fallback: if MediaStore fails, keep temp file
      return tempFile;
    }

    // Windows/macOS/Linux: save to Downloads/LANLine
    final dir = await getDownloadsDirectory();
    final saveDir = dir != null ? p.join(dir.path, 'LANLine') : p.join((await getApplicationDocumentsDirectory()).path, 'LANLine_Downloads');
    final file = File(p.join(saveDir, filename));
    if (!await file.parent.exists()) await file.parent.create(recursive: true);
    return await file.writeAsBytes(bytes);
  }
}
