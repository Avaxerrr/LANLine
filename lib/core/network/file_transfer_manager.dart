import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

final fileTransferProvider = Provider<FileTransferManager>((ref) => FileTransferManager());

class FileTransferManager {
  // Using 256 KB chunks to ensure WebSocket frames aren't dropped and Base64 overhead is negligible
  static const int chunkSize = 1024 * 256; 

  // Maps filename -> expanding byte list
  final Map<String, BytesBuilder> _incomingFiles = {};

  /// Reads a file from disk and breaks it into an array of JSON Base64 payloads
  Future<List<String>> splitFileIntoChunks(File file, String sender, {String? offerId}) async {
    final filename = p.basename(file.path);
    final bytes = await file.readAsBytes();
    final totalChunks = (bytes.length / chunkSize).ceil();
    
    // Handle empty files safely
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
      if (offerId != null) {
        payloadMap['offer_id'] = offerId;
      }
      payloads.add(jsonEncode(payloadMap));
    }
    return payloads;
  }

  /// Parses an incoming file chunk, stores it in memory, and triggers save if complete.
  /// Returns the saved File object if this chunk completed the transfer, otherwise null.
  Future<File?> handleChunk(Map<String, dynamic> data, {String? customTestSavePath}) async {
    final filename = data['filename'] as String;
    final totalChunks = data['total_chunks'] as int;
    final chunkIndex = data['chunk_index'] as int;
    final base64Data = data['data'] as String;
    
    // Initialize array if this is chunk 0
    _incomingFiles.putIfAbsent(filename, () => BytesBuilder());
    
    final chunkBytes = base64Decode(base64Data);
    _incomingFiles[filename]!.add(chunkBytes);
    
    // If we've received the last chunk
    if (chunkIndex == totalChunks - 1) {
      final completeBytes = _incomingFiles.remove(filename)!.takeBytes();
      return await _saveFile(filename, completeBytes, customSavePath: customTestSavePath);
    }
    
    return null;
  }

  Future<File> _saveFile(String filename, List<int> bytes, {String? customSavePath}) async {
    String saveDir;
    
    if (customSavePath != null) {
      // Used purely for unit testing the logic without triggering OS path_provider locks
      saveDir = customSavePath;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      saveDir = p.join(directory.path, 'LANLine_Downloads');
    }
    
    final file = File(p.join(saveDir, filename));
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return await file.writeAsBytes(bytes);
  }
}
