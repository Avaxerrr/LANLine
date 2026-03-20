import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/network/file_transfer_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FileTransferManager Headless Verification', () {
    late FileTransferManager manager;
    late Directory tempDir;
    late File dummyFile;

    setUp(() async {
      manager = FileTransferManager();
      tempDir = await Directory.systemTemp.createTemp('lanline_test_');
      
      // Generate a dummy 2MB binary file to simulate a photo/video
      final bytes = List<int>.generate(1024 * 2000, (i) => i % 256);
      dummyFile = File(p.join(tempDir.path, 'test_video.mp4'));
      await dummyFile.writeAsBytes(bytes);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Perfectly chunks, transmits, and reconstructs a binary file byte-for-byte', () async {
      // 1. Sender chunks the file
      final payloads = await manager.splitFileIntoChunks(dummyFile, 'TestUser');
      
      // The 2000KB file should be strictly split into around 8 chunks (since limit is 256KB)
      expect(payloads.length, greaterThan(5));
      
      File? reconstructedFile;
      
      // 2. Simulated WebSocket Mesh Loop - Sender fires payloads to Receiver
      for (var payload in payloads) {
        final decodedJson = jsonDecode(payload);
        expect(decodedJson['type'], 'file_chunk');
        
        // Receiver handles the chunk
        final result = await manager.handleChunk(
          decodedJson, 
          customTestSavePath: tempDir.path // Overriding path_provider for isolated testing
        );
        
        if (result != null) {
          reconstructedFile = result;
        }
      }
      
      // 3. Post-Transmission Verification
      expect(reconstructedFile, isNotNull, reason: 'The file transfer failed to complete and return a File');
      expect(await reconstructedFile!.exists(), isTrue);
      
      // 4. Absolute Byte-for-Byte integrity check to ensure Base64 caused no corruption
      final originalBytes = await dummyFile.readAsBytes();
      final reconstructedBytes = await reconstructedFile.readAsBytes();
      
      expect(originalBytes.length, reconstructedBytes.length);
      expect(originalBytes, equals(reconstructedBytes), reason: 'Data corruption detected in chunk reconstruction');
    });
  });
}
