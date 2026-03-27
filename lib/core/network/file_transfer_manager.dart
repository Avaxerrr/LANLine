import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../services/media_store_service.dart';

final fileTransferProvider = Provider<FileTransferManager>((ref) {
  final manager = FileTransferManager();
  ref.onDispose(manager.dispose);
  return manager;
});

typedef FileTransferProgressCallback =
    void Function(int bytesReceived, int totalBytes);

class PreparedFileTransfer {
  final String token;
  final String path;

  const PreparedFileTransfer({required this.token, required this.path});
}

/// Called when the sender has fully served a file to the receiver via HTTP.
typedef OutgoingTransferServedCallback = void Function(String attachmentId);

class FileTransferManager {
  static const String transferPathPrefix = '/v2/media/files';
  static const Duration transferTimeout = Duration(minutes: 30);

  final HttpClient _httpClient;
  final Uuid _uuid;
  final Map<String, _OutgoingTransferSession> _outgoingTransfers = {};
  final Map<String, _ActiveDownload> _activeDownloads = {};

  /// Fires after a file has been fully streamed to the receiver via HTTP.
  OutgoingTransferServedCallback? onOutgoingTransferServed;

  FileTransferManager({HttpClient? httpClient, Uuid? uuid})
    : _httpClient = httpClient ?? HttpClient(),
      _uuid = uuid ?? const Uuid();

  static String sanitizeFilename(String raw) {
    var name = p.basename(raw).trim();
    name = name.replaceAll(RegExp(r'[/\\:\x00]'), '_');
    if (name.isEmpty || name == '.' || name == '..') {
      name = 'unnamed_file';
    }
    if (name.length > 255) {
      final ext = p.extension(name);
      name = '${name.substring(0, 255 - ext.length)}$ext';
    }
    return name;
  }

  Future<PreparedFileTransfer> prepareOutgoingTransfer({
    required String attachmentId,
    required String filePath,
    required String fileName,
    String? mimeType,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('The selected file no longer exists.');
    }

    _cleanupExpiredTransfers();

    final token = _uuid.v4();
    final session = _OutgoingTransferSession(
      attachmentId: attachmentId,
      filePath: file.path,
      fileName: sanitizeFilename(fileName),
      mimeType: mimeType,
      createdAt: DateTime.now(),
    );

    _outgoingTransfers[token] = session;
    return PreparedFileTransfer(
      token: token,
      path: '$transferPathPrefix/$token',
    );
  }

  Future<bool> handleHttpRequest(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (request.method != 'GET' ||
        segments.length != 4 ||
        segments[0] != 'v2' ||
        segments[1] != 'media' ||
        segments[2] != 'files') {
      return false;
    }

    _cleanupExpiredTransfers();

    final token = segments[3];
    final session = _outgoingTransfers.remove(token);
    if (session == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return true;
    }

    final file = File(session.filePath);
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.gone;
      await request.response.close();
      return true;
    }

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = _resolveContentType(
      session.mimeType,
    );
    request.response.headers.set(
      'content-disposition',
      'attachment; filename="${session.fileName}"',
    );
    request.response.contentLength = await file.length();

    try {
      await request.response.addStream(file.openRead());
      // File fully served — notify so the sender can mark transfer as completed
      // even if the receiver's file_downloaded signal is lost.
      onOutgoingTransferServed?.call(session.attachmentId);
    } finally {
      await request.response.close();
    }
    return true;
  }

  Future<File> downloadFile({
    required String host,
    required int port,
    required String transferPath,
    required String attachmentId,
    required String fileName,
    FileTransferProgressCallback? onProgress,
    String? customTestSavePath,
  }) async {
    cancelFile(attachmentId);

    final sanitizedName = sanitizeFilename(fileName);
    final destination = await _createDestinationFile(
      sanitizedName,
      customSavePath: customTestSavePath,
    );

    HttpClientRequest? request;
    IOSink? sink;
    StreamSubscription<List<int>>? subscription;

    try {
      request = await _httpClient.get(host, port, transferPath);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'File download failed with status ${response.statusCode}.',
          uri: response.redirects.isNotEmpty
              ? response.redirects.last.location
              : Uri(scheme: 'http', host: host, port: port, path: transferPath),
        );
      }

      final totalBytes = response.contentLength >= 0
          ? response.contentLength
          : 0;
      sink = destination.openWrite();
      final completer = Completer<File>();
      final activeDownload = _ActiveDownload(
        attachmentId: attachmentId,
        file: destination,
      );
      _activeDownloads[attachmentId] = activeDownload;

      var bytesReceived = 0;
      subscription = response.listen(
        (chunk) {
          if (activeDownload.isCancelled) return;
          bytesReceived += chunk.length;
          sink!.add(chunk);
          if (onProgress != null && totalBytes > 0) {
            onProgress(bytesReceived, totalBytes);
          }
        },
        onError: (Object error, StackTrace stackTrace) async {
          await _cleanupActiveDownload(
            attachmentId,
            sink: sink,
            file: destination,
            deletePartialFile: true,
          );
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
        onDone: () async {
          if (activeDownload.isCancelled) {
            await _cleanupActiveDownload(
              attachmentId,
              sink: sink,
              file: destination,
              deletePartialFile: true,
            );
            if (!completer.isCompleted) {
              completer.completeError(
                StateError('File transfer was cancelled.'),
              );
            }
            return;
          }

          await sink!.flush();
          await sink.close();
          _activeDownloads.remove(attachmentId);

          try {
            final savedFile = await _finalizeDownloadedFile(
              destination,
              sanitizedName,
              customSavePath: customTestSavePath,
            );
            if (onProgress != null && totalBytes > 0) {
              onProgress(totalBytes, totalBytes);
            }
            if (!completer.isCompleted) {
              completer.complete(savedFile);
            }
          } catch (error, stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          }
        },
        cancelOnError: true,
      );

      activeDownload.subscription = subscription;
      return await completer.future;
    } catch (_) {
      await subscription?.cancel();
      await _cleanupActiveDownload(
        attachmentId,
        sink: sink,
        file: destination,
        deletePartialFile: true,
      );
      rethrow;
    }
  }

  void cancelFile(String attachmentId) {
    final outgoingToken = _outgoingTransfers.entries
        .where((entry) => entry.value.attachmentId == attachmentId)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final token in outgoingToken) {
      _outgoingTransfers.remove(token);
    }

    final activeDownload = _activeDownloads.remove(attachmentId);
    if (activeDownload == null) return;

    activeDownload.isCancelled = true;
    unawaited(activeDownload.subscription?.cancel());
    unawaited(
      activeDownload.file.delete().catchError((_) => activeDownload.file),
    );
  }

  void dispose() {
    for (final attachmentId in _activeDownloads.keys.toList(growable: false)) {
      cancelFile(attachmentId);
    }
    _outgoingTransfers.clear();
    _httpClient.close(force: true);
  }

  void _cleanupExpiredTransfers() {
    final now = DateTime.now();
    final expiredTokens = _outgoingTransfers.entries
        .where(
          (entry) => now.difference(entry.value.createdAt) > transferTimeout,
        )
        .map((entry) => entry.key)
        .toList(growable: false);

    for (final token in expiredTokens) {
      _outgoingTransfers.remove(token);
    }
  }

  Future<File> _createDestinationFile(
    String rawFilename, {
    String? customSavePath,
  }) async {
    final filename = sanitizeFilename(rawFilename);
    if (customSavePath != null) {
      final file = File(p.join(customSavePath, filename));
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      return file;
    }

    if (Platform.isAndroid) {
      final tempDir = await getApplicationCacheDirectory();
      final file = File(
        p.join(
          tempDir.path,
          'lanline_http_${DateTime.now().microsecondsSinceEpoch}_$filename',
        ),
      );
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      return file;
    }

    final dir = await getDownloadsDirectory();
    final saveDir = dir != null
        ? p.join(dir.path, 'LANLine')
        : p.join(
            (await getApplicationDocumentsDirectory()).path,
            'LANLine_Downloads',
          );
    final file = File(p.join(saveDir, filename));
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    return file;
  }

  Future<File> _finalizeDownloadedFile(
    File tempFile,
    String filename, {
    String? customSavePath,
  }) async {
    if (customSavePath != null || !Platform.isAndroid) {
      return tempFile;
    }

    final uri = await MediaStoreService.saveToDownloads(
      tempFile.path,
      filename,
    );
    if (uri != null) {
      final publicPath = await MediaStoreService.getDownloadsPath();
      return File(p.join(publicPath ?? tempFile.parent.path, filename));
    }
    return tempFile;
  }

  Future<void> _cleanupActiveDownload(
    String attachmentId, {
    required IOSink? sink,
    required File file,
    required bool deletePartialFile,
  }) async {
    _activeDownloads.remove(attachmentId);
    try {
      await sink?.close();
    } catch (_) {}
    if (!deletePartialFile) return;
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  ContentType _resolveContentType(String? mimeType) {
    if (mimeType == null || mimeType.trim().isEmpty) {
      return ContentType.binary;
    }

    final parts = mimeType.split('/');
    if (parts.length != 2) {
      return ContentType.binary;
    }
    return ContentType(parts[0], parts[1]);
  }
}

class _OutgoingTransferSession {
  final String attachmentId;
  final String filePath;
  final String fileName;
  final String? mimeType;
  final DateTime createdAt;

  const _OutgoingTransferSession({
    required this.attachmentId,
    required this.filePath,
    required this.fileName,
    required this.mimeType,
    required this.createdAt,
  });
}

class _ActiveDownload {
  final String attachmentId;
  final File file;
  StreamSubscription<List<int>>? subscription;
  bool isCancelled;

  _ActiveDownload({required this.attachmentId, required this.file})
    : isCancelled = false;
}
