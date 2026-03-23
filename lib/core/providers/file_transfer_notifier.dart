import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../models/chat_message.dart';
import '../network/file_transfer_manager.dart';
import 'chat_provider.dart';
import 'download_history_provider.dart';
import 'username_provider.dart';

/// Configuration for the file transfer notifier.
class FileTransferConfig {
  final String roomName;
  const FileTransferConfig({required this.roomName});
}

/// State for file transfer tracking.
class FileTransferState {
  /// Sender-side: offerId → local file path for pending large-file offers.
  final Map<String, String> pendingFileOffers;

  /// Download progress: offerId → [receivedChunks, totalChunks].
  final Map<String, List<int>> downloadProgress;

  /// Offers that have been cancelled (by either side).
  final Set<String> cancelledOffers;

  /// Offers that WE accepted (receiver side).
  final Set<String> acceptedOffers;

  const FileTransferState({
    this.pendingFileOffers = const {},
    this.downloadProgress = const {},
    this.cancelledOffers = const {},
    this.acceptedOffers = const {},
  });

  FileTransferState copyWith({
    Map<String, String>? pendingFileOffers,
    Map<String, List<int>>? downloadProgress,
    Set<String>? cancelledOffers,
    Set<String>? acceptedOffers,
  }) {
    return FileTransferState(
      pendingFileOffers: pendingFileOffers ?? this.pendingFileOffers,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      cancelledOffers: cancelledOffers ?? this.cancelledOffers,
      acceptedOffers: acceptedOffers ?? this.acceptedOffers,
    );
  }
}

/// Manages file transfer state: sending, receiving, offer/accept/cancel flow,
/// and download progress tracking.
class FileTransferNotifier extends Notifier<FileTransferState> {
  FileTransferConfig? _config;
  Timer? _progressThrottleTimer;
  bool _progressDirty = false;

  /// Internal mutable progress map — flushed to state every 200ms to
  /// avoid excessive rebuilds during rapid chunk reception.
  final Map<String, List<int>> _progressInternal = {};

  /// Files above this threshold use the offer/accept flow instead of
  /// auto-sending.
  static const int autoDownloadThreshold = 10 * 1024 * 1024;

  @override
  FileTransferState build() => const FileTransferState();

  void init(FileTransferConfig config) {
    _config = config;
  }

  void dispose() {
    _progressThrottleTimer?.cancel();
    _progressThrottleTimer = null;
    _progressInternal.clear();
  }

  // ── Sending ──────────────────────────────────────────────────

  /// Send a file to all participants. Large files (>10 MB) go through
  /// the offer/accept flow; small files are sent immediately.
  Future<void> sendFile(File file) async {
    final filename = p.basename(file.path);
    final senderName = ref.read(usernameProvider);
    final fileSize = await file.length();
    final chat = ref.read(chatProvider.notifier);

    if (fileSize > autoDownloadThreshold) {
      final offerId = '${DateTime.now().millisecondsSinceEpoch}_${filename.hashCode}';
      state = state.copyWith(
        pendingFileOffers: {...state.pendingFileOffers, offerId: file.path},
      );

      final offerPayload = jsonEncode({
        'type': 'file_offer',
        'sender': senderName,
        'filename': filename,
        'size': fileSize,
        'offer_id': offerId,
      });

      chat.broadcast(offerPayload);
      chat.addMessage(ChatMessage(
        sender: senderName, text: '', isMe: true,
        fileName: '📤 $filename (${formatFileSize(fileSize)})',
        fileSize: fileSize, offerId: offerId,
      ));
    } else {
      chat.addMessage(ChatMessage(
        sender: senderName, text: '', isMe: true,
        filePath: file.path,
        fileName: '📤 $filename (${formatFileSize(fileSize)})',
      ));

      final manager = ref.read(fileTransferProvider);
      final payloads = await manager.splitFileIntoChunks(file, senderName);
      for (var payload in payloads) {
        chat.broadcast(payload);
      }
    }
  }

  /// Accept a pending file offer (receiver side). Broadcasts accept
  /// and marks the message as downloading.
  void acceptFileOffer(String offerId) {
    state = state.copyWith(
      acceptedOffers: {...state.acceptedOffers, offerId},
    );

    final acceptPayload = jsonEncode({
      'type': 'accept_file',
      'offer_id': offerId,
    });

    final chat = ref.read(chatProvider.notifier);
    chat.broadcast(acceptPayload);

    final idx = chat.findMessageIndex(offerId, isMe: false);
    if (idx != -1) {
      final old = ref.read(chatProvider).messages[idx];
      chat.updateMessageAt(idx, ChatMessage(
        sender: old.sender, text: '', isMe: false,
        fileName: old.fileName, fileSize: old.fileSize,
        offerId: offerId, isDownloading: true,
      ));
    }
  }

  /// Cancel a file offer (either side). Broadcasts cancel and marks
  /// the message as cancelled.
  void cancelFileOffer(String offerId) {
    final updatedCancelled = {...state.cancelledOffers, offerId};
    final updatedPending = Map<String, String>.from(state.pendingFileOffers)..remove(offerId);
    final updatedProgress = Map<String, List<int>>.from(state.downloadProgress)..remove(offerId);
    _progressInternal.remove(offerId);

    state = state.copyWith(
      cancelledOffers: updatedCancelled,
      pendingFileOffers: updatedPending,
      downloadProgress: updatedProgress,
    );

    final cancelPayload = jsonEncode({
      'type': 'cancel_file',
      'offer_id': offerId,
    });

    final chat = ref.read(chatProvider.notifier);
    chat.broadcast(cancelPayload);
    chat.updateMessageByOfferId(offerId, (old) => ChatMessage(
      sender: old.sender, text: '', isMe: old.isMe,
      fileName: old.fileName, fileSize: old.fileSize,
      offerId: offerId, isCancelled: true,
    ));
  }

  // ── Incoming file messages ─────────────────────────────────

  /// Handle an incoming file-related message. Returns:
  /// - `'file_received'` when a file transfer completes (scroll + notify)
  /// - `'file_offer'` when a file offer arrives (scroll + notify)
  /// - `'file_downloaded'` when someone downloaded our file (snackbar)
  /// - `'file_chunk'` for in-progress chunks (no UI needed)
  /// - `'accept_file'` / `'cancel_file'` for state updates (no UI needed)
  /// - `null` if not a file type
  Future<String?> handleFileMessage(String rawMessage) async {
    try {
      final data = jsonDecode(rawMessage);
      final type = data['type'] as String?;

      switch (type) {
        case 'file_chunk':
          return await _handleFileChunk(data);
        case 'file_offer':
          _handleFileOffer(data);
          return type;
        case 'accept_file':
          await _handleAcceptFile(data);
          return type;
        case 'file_downloaded':
          _handleFileDownloaded(data);
          return type;
        case 'cancel_file':
          _handleCancelFile(data);
          return type;
        default:
          return null;
      }
    } catch (e) {
      debugPrint('Error handling file message: $e');
      return null;
    }
  }

  /// Returns 'file_received' if transfer completed, 'file_chunk' otherwise.
  Future<String> _handleFileChunk(Map<String, dynamic> data) async {
    final offerId = data['offer_id'] as String?;

    // Skip chunks for cancelled offers
    if (offerId != null && state.cancelledOffers.contains(offerId)) return 'file_chunk';

    // For offer-based downloads, only process if WE accepted it
    if (offerId != null && !state.acceptedOffers.contains(offerId)) return 'file_chunk';

    // Track progress (throttled)
    if (offerId != null) {
      final total = data['total_chunks'] as int;
      final chunkIdx = data['chunk_index'] as int;
      _progressInternal[offerId] = [chunkIdx + 1, total];
      _progressDirty = true;
      _progressThrottleTimer ??= Timer.periodic(
        const Duration(milliseconds: 200),
        (_) {
          if (_progressDirty) {
            _progressDirty = false;
            state = state.copyWith(downloadProgress: Map.from(_progressInternal));
          }
        },
      );
    }

    final manager = ref.read(fileTransferProvider);
    final completeFile = await manager.handleChunk(data);
    if (completeFile != null) {
      final sender = data['sender'] as String;
      final filename = data['filename'] as String;
      if (offerId != null) {
        _progressInternal.remove(offerId);
        state = state.copyWith(downloadProgress: Map.from(_progressInternal));
      }

      _logDownload(filename, completeFile.path, sender);

      final chat = ref.read(chatProvider.notifier);
      if (offerId != null) {
        final idx = chat.findMessageIndex(offerId, isMe: false);
        if (idx != -1) {
          chat.updateMessageAt(idx, ChatMessage(
            sender: sender, text: '', isMe: false,
            filePath: completeFile.path, fileName: filename, offerId: offerId,
          ));
        } else {
          chat.addMessage(ChatMessage(
            sender: sender, text: '', isMe: false,
            filePath: completeFile.path, fileName: filename,
          ));
        }
      } else {
        chat.addMessage(ChatMessage(
          sender: sender, text: '', isMe: false,
          filePath: completeFile.path, fileName: filename,
        ));
      }

      // Send file_downloaded ack
      final downloadedPayload = jsonEncode({
        'type': 'file_downloaded',
        'offer_id': offerId,
        'downloader': ref.read(usernameProvider),
        'filename': filename,
      });
      chat.broadcast(downloadedPayload);

      return 'file_received';
    }

    return 'file_chunk';
  }

  void _handleFileOffer(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final filename = data['filename'] as String;
    final fileSize = data['size'] as int;
    final offerId = data['offer_id'] as String;

    ref.read(chatProvider.notifier).addMessage(ChatMessage(
      sender: sender, text: '', isMe: false,
      fileName: filename, fileSize: fileSize, offerId: offerId,
    ));
  }

  Future<void> _handleAcceptFile(Map<String, dynamic> data) async {
    final offerId = data['offer_id'] as String;
    final filePath = state.pendingFileOffers[offerId];
    if (filePath != null) {
      final file = File(filePath);
      if (await file.exists()) {
        final senderName = ref.read(usernameProvider);
        final manager = ref.read(fileTransferProvider);
        final payloads = await manager.splitFileIntoChunks(file, senderName, offerId: offerId);
        final chat = ref.read(chatProvider.notifier);
        for (var payload in payloads) {
          chat.broadcast(payload);
        }
      }
    }
  }

  void _handleFileDownloaded(Map<String, dynamic> data) {
    final offerId = data['offer_id'] as String?;
    if (offerId != null) {
      ref.read(chatProvider.notifier).updateMessageByOfferId(offerId, (old) => ChatMessage(
        sender: old.sender, text: '', isMe: true,
        fileName: old.fileName, fileSize: old.fileSize, offerId: offerId,
        filePath: old.filePath ?? state.pendingFileOffers[offerId],
      ), senderOnly: true);
    }
  }

  void _handleCancelFile(Map<String, dynamic> data) {
    final offerId = data['offer_id'] as String;
    final updatedCancelled = {...state.cancelledOffers, offerId};
    final updatedPending = Map<String, String>.from(state.pendingFileOffers)..remove(offerId);
    final updatedProgress = Map<String, List<int>>.from(state.downloadProgress)..remove(offerId);
    _progressInternal.remove(offerId);

    state = state.copyWith(
      cancelledOffers: updatedCancelled,
      pendingFileOffers: updatedPending,
      downloadProgress: updatedProgress,
    );

    ref.read(chatProvider.notifier).updateMessageByOfferId(offerId, (old) => ChatMessage(
      sender: old.sender, text: '', isMe: old.isMe,
      fileName: old.fileName, fileSize: old.fileSize, offerId: offerId,
      isCancelled: true,
    ));
  }

  void _logDownload(String filename, String filePath, String sender) {
    final fileSize = File(filePath).lengthSync();
    ref.read(downloadHistoryProvider.notifier).addRecord(DownloadRecord(
      fileName: filename,
      filePath: filePath,
      fileSize: fileSize,
      senderName: sender,
      roomName: _config?.roomName ?? '',
      downloadedAt: DateTime.now(),
    ));
  }
}

final fileTransferNotifierProvider =
    NotifierProvider<FileTransferNotifier, FileTransferState>(() {
  return FileTransferNotifier();
});
