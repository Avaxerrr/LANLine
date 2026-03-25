import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/network/file_transfer_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  group('FileTransferManager HTTP transfer', () {
    late FileTransferManager manager;
    late Directory tempDir;
    late File dummyFile;
    HttpServer? server;

    setUp(() async {
      manager = FileTransferManager();
      tempDir = await Directory.systemTemp.createTemp('lanline_http_test_');

      final bytes = List<int>.generate(1024 * 2000, (i) => i % 256);
      dummyFile = File(p.join(tempDir.path, 'test_video.mp4'));
      await dummyFile.writeAsBytes(bytes);

      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server!.listen((request) async {
        final handled = await manager.handleHttpRequest(request);
        if (!handled) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      });
    });

    tearDown(() async {
      await server?.close(force: true);
      manager.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'streams a file over HTTP and reconstructs it byte-for-byte',
      () async {
        final prepared = await manager.prepareOutgoingTransfer(
          attachmentId: 'sender-attachment-1',
          filePath: dummyFile.path,
          fileName: 'test_video.mp4',
          mimeType: 'video/mp4',
        );

        final progressEvents = <List<int>>[];
        final downloadedFile = await manager.downloadFile(
          host: InternetAddress.loopbackIPv4.address,
          port: server!.port,
          transferPath: prepared.path,
          attachmentId: 'receiver-attachment-1',
          fileName: 'received_video.mp4',
          customTestSavePath: tempDir.path,
          onProgress: (bytesReceived, totalBytes) {
            progressEvents.add([bytesReceived, totalBytes]);
          },
        );

        expect(await downloadedFile.exists(), isTrue);
        expect(progressEvents, isNotEmpty);
        expect(progressEvents.last[0], progressEvents.last[1]);

        final originalBytes = await dummyFile.readAsBytes();
        final reconstructedBytes = await downloadedFile.readAsBytes();

        expect(reconstructedBytes.length, originalBytes.length);
        expect(reconstructedBytes, equals(originalBytes));
      },
    );
  });
}
