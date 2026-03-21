import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/models/room_model.dart';
import '../../../core/network/websocket_server.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/network/discovery_service.dart';
import '../../../core/providers/username_provider.dart';
import '../../../core/network/file_transfer_manager.dart';
import '../../../core/providers/download_history_provider.dart';
import '../../../core/services/notification_service.dart';
import 'package:share_plus/share_plus.dart';

class ChatMessage {
  final String? id;
  final String sender;
  final String text;
  final bool isMe;
  final String? filePath;
  final String? fileName;
  final String? offerId;
  final int? fileSize;
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
    this.isAcked = false,
    this.isDownloading = false,
    this.isExpired = false,
    this.isCancelled = false,
  });
}

class ChatScreen extends ConsumerStatefulWidget {
  final bool isHost;
  final Room room;
  const ChatScreen({super.key, required this.isHost, required this.room});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  final Set<String> _typingUsers = {};
  bool _isDragging = false;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _localIp;
  int _participantCount = 0;

  // File threshold: 10 MB
  static const int _autoDownloadThreshold = 10 * 1024 * 1024;

  // Sender keeps track of pending file offers (offerId -> filePath)
  final Map<String, String> _pendingFileOffers = {};

  // Download progress tracking (offerId -> [received, total])
  final Map<String, List<int>> _downloadProgress = {};

  // Cancelled and accepted offers
  final Set<String> _cancelledOffers = {};
  final Set<String> _acceptedOffers = {};

  // Throttle for progress updates to avoid excessive rebuilds
  Timer? _progressThrottleTimer;
  bool _progressDirty = false;

  bool get _hasParticipants => _participantCount > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocalIp();
    NotificationService().initialize();

    // Client always has at least the host as a participant
    if (!widget.isHost) {
      _participantCount = 1;
    }

    final stream = widget.isHost
        ? ref.read(webSocketServerProvider).onMessageReceived
        : ref.read(webSocketClientProvider).onMessageReceived;

    stream.listen((message) {
      if (mounted) {
        _handleIncomingMessage(message);
      }
    });

    // Host tracks participant count from the server directly
    if (widget.isHost) {
      ref.read(webSocketServerProvider).onParticipantCountChanged.listen((count) {
        if (mounted) {
          setState(() => _participantCount = count);
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    NotificationService().appInForeground = state == AppLifecycleState.resumed;
  }

  Future<void> _loadLocalIp() async {
    final ip = await ref.read(discoveryServiceProvider).getLocalIpAddress();
    if (mounted) setState(() => _localIp = ip);
  }

  void _showTopSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleIncomingMessage(String rawMessage) async {
    try {
      final data = jsonDecode(rawMessage);
      if (data['type'] == 'typing') {
        final sender = data['sender'];
        final changed = _typingUsers.add(sender);
        if (changed) setState(() {});
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _typingUsers.remove(sender)) {
            setState(() {});
          }
        });
      } else if (data['type'] == 'ack') {
        final id = data['id'];
        setState(() {
          for (var msg in _messages) {
            if (msg.id == id && msg.isMe) {
              msg.isAcked = true;
              break;
            }
          }
        });
      } else if (data['type'] == 'participant_count') {
        if (!widget.isHost) {
          final count = data['count'] as int;
          setState(() => _participantCount = count - 1);
        }
      } else if (data['type'] == 'error') {
        setState(() {
          _messages.add(ChatMessage(sender: "System", text: data['text'], isMe: false));
        });
        _scrollToBottom();
      } else if (data['type'] == 'message') {
        final sender = data['sender'];
        final text = data['text'];
        final msgId = data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

        setState(() {
          _typingUsers.remove(sender);
          _messages.add(ChatMessage(id: msgId, sender: sender, text: text, isMe: false));
        });
        _scrollToBottom();

        // Send notification
        NotificationService().showMessageNotification(
          sender: sender,
          message: text,
          roomName: widget.room.name,
        );

        final ackPayload = jsonEncode({'type': 'ack', 'id': msgId});
        if (widget.isHost) {
          ref.read(webSocketServerProvider).broadcastMessage(ackPayload);
        } else {
          ref.read(webSocketClientProvider).sendMessage(ackPayload);
        }
      } else if (data['type'] == 'file_chunk') {
        final offerId = data['offer_id'] as String?;

        // Skip chunks for cancelled offers
        if (offerId != null && _cancelledOffers.contains(offerId)) return;

        // For offer-based downloads, only process if WE accepted it
        if (offerId != null && !_acceptedOffers.contains(offerId)) return;

        // Track progress for offer-based downloads (throttled)
        if (offerId != null) {
          final total = data['total_chunks'] as int;
          final chunkIdx = data['chunk_index'] as int;
          _downloadProgress[offerId] = [chunkIdx + 1, total];
          _progressDirty = true;
          _progressThrottleTimer ??= Timer.periodic(
            const Duration(milliseconds: 200),
            (_) {
              if (_progressDirty && mounted) {
                _progressDirty = false;
                setState(() {});
              }
            },
          );
        }

        final manager = ref.read(fileTransferProvider);
        final completeFile = await manager.handleChunk(data);
        if (completeFile != null) {
          final sender = data['sender'] as String;
          final filename = data['filename'] as String;
          if (offerId != null) _downloadProgress.remove(offerId);

          // Log to download history
          _logDownload(filename, completeFile.path, sender);

          setState(() {
            if (offerId != null) {
              final idx = _messages.indexWhere((m) => m.offerId == offerId && !m.isMe);
              if (idx != -1) {
                _messages[idx] = ChatMessage(
                  sender: sender, text: '', isMe: false,
                  filePath: completeFile.path, fileName: filename, offerId: offerId,
                );
              } else {
                _messages.add(ChatMessage(
                  sender: sender, text: '', isMe: false,
                  filePath: completeFile.path, fileName: filename,
                ));
              }
            } else {
              _messages.add(ChatMessage(
                sender: sender, text: '', isMe: false,
                filePath: completeFile.path, fileName: filename,
              ));
            }
          });
          _scrollToBottom();

          // Send file_downloaded ack back to everyone
          final downloadedPayload = jsonEncode({
            'type': 'file_downloaded',
            'offer_id': offerId,
            'downloader': ref.read(usernameProvider),
            'filename': filename,
          });
          if (widget.isHost) {
            ref.read(webSocketServerProvider).broadcastMessage(downloadedPayload);
          } else {
            ref.read(webSocketClientProvider).sendMessage(downloadedPayload);
          }

          // Notify if app is backgrounded
          NotificationService().showFileNotification(sender: sender, fileName: filename);
        }
      } else if (data['type'] == 'file_offer') {
        final sender = data['sender'] as String;
        final filename = data['filename'] as String;
        final fileSize = data['size'] as int;
        final offerId = data['offer_id'] as String;
        setState(() {
          _messages.add(ChatMessage(
            sender: sender, text: '', isMe: false,
            fileName: filename, fileSize: fileSize, offerId: offerId,
          ));
        });
        _scrollToBottom();

        NotificationService().showFileNotification(
          sender: sender, fileName: '$filename (${_formatFileSize(fileSize)})', isOffer: true,
        );
      } else if (data['type'] == 'accept_file') {
        final offerId = data['offer_id'] as String;
        final filePath = _pendingFileOffers[offerId]; // Don't remove yet — might be multi-user
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            final senderName = ref.read(usernameProvider);
            final manager = ref.read(fileTransferProvider);
            final payloads = await manager.splitFileIntoChunks(file, senderName, offerId: offerId);
            for (var payload in payloads) {
              if (widget.isHost) {
                ref.read(webSocketServerProvider).broadcastMessage(payload);
              } else {
                ref.read(webSocketClientProvider).sendMessage(payload);
              }
            }
          }
        }
      } else if (data['type'] == 'file_downloaded') {
        // Someone finished downloading our file — update sender state
        final offerId = data['offer_id'] as String?;
        final downloader = data['downloader'] as String? ?? 'Someone';
        if (offerId != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.offerId == offerId && m.isMe);
            if (idx != -1) {
              final old = _messages[idx];
              _messages[idx] = ChatMessage(
                sender: old.sender, text: '', isMe: true,
                fileName: old.fileName, fileSize: old.fileSize, offerId: offerId,
                filePath: old.filePath ?? _pendingFileOffers[offerId],
              );
            }
          });
          _showTopSnackBar('✅ $downloader downloaded the file');
        }
      } else if (data['type'] == 'cancel_file') {
        final offerId = data['offer_id'] as String;
        _cancelledOffers.add(offerId);
        _pendingFileOffers.remove(offerId);
        _downloadProgress.remove(offerId);
        setState(() {
          for (int i = 0; i < _messages.length; i++) {
            if (_messages[i].offerId == offerId) {
              final old = _messages[i];
              _messages[i] = ChatMessage(
                sender: old.sender, text: '', isMe: old.isMe,
                fileName: old.fileName, fileSize: old.fileSize, offerId: offerId,
                isCancelled: true,
              );
            }
          }
        });
      } else if (data['type'] == 'clipboard') {
        final sender = data['sender'] as String;
        final text = data['text'] as String;
        await Clipboard.setData(ClipboardData(text: text));
        setState(() {
          _messages.add(ChatMessage(sender: sender, text: "📋 Automatically Copied to Clipboard:\n$text", isMe: false));
        });
        _scrollToBottom();
      }
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(sender: "Peer", text: rawMessage, isMe: false));
      });
      _scrollToBottom();
    }
  }

  void _logDownload(String filename, String filePath, String sender) {
    final fileSize = File(filePath).lengthSync();
    ref.read(downloadHistoryProvider.notifier).addRecord(DownloadRecord(
      fileName: filename,
      filePath: filePath,
      fileSize: fileSize,
      senderName: sender,
      roomName: widget.room.name,
      downloadedAt: DateTime.now(),
    ));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    if (!_hasParticipants) {
      _showTopSnackBar('No one else is in the room');
      return;
    }

    final name = ref.read(usernameProvider);
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = jsonEncode({'type': 'message', 'id': msgId, 'sender': name, 'text': text});

    if (widget.isHost) {
      ref.read(webSocketServerProvider).broadcastMessage(payload);
    } else {
      ref.read(webSocketClientProvider).sendMessage(payload);
    }

    setState(() {
      _messages.add(ChatMessage(id: msgId, sender: name, text: text, isMe: true));
    });
    _textController.clear();
    _scrollToBottom();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressThrottleTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _textController.dispose();
    _scrollController.dispose();

    if (widget.isHost) {
      ref.read(discoveryServiceProvider).stop();
      ref.read(webSocketServerProvider).stopServer();
    } else {
      ref.read(webSocketClientProvider).disconnect();
    }
    super.dispose();
  }

  void _showNoParticipantsWarning() {
    _showTopSnackBar('No one else is in the room');
  }

  Future<void> _handleDroppedFiles(List<File> files) async {
    if (!_hasParticipants) {
      _showNoParticipantsWarning();
      return;
    }
    for (var file in files) {
      await _sendFile(file);
    }
  }

  Future<void> _sendFile(File file) async {
    final filename = p.basename(file.path);
    final senderName = ref.read(usernameProvider);
    final fileSize = await file.length();

    if (fileSize > _autoDownloadThreshold) {
      // Large file: send offer only, wait for accept
      final offerId = '${DateTime.now().millisecondsSinceEpoch}_${filename.hashCode}';
      _pendingFileOffers[offerId] = file.path;

      final offerPayload = jsonEncode({
        'type': 'file_offer',
        'sender': senderName,
        'filename': filename,
        'size': fileSize,
        'offer_id': offerId,
      });

      if (widget.isHost) {
        ref.read(webSocketServerProvider).broadcastMessage(offerPayload);
      } else {
        ref.read(webSocketClientProvider).sendMessage(offerPayload);
      }

      setState(() {
        _messages.add(ChatMessage(
          sender: senderName, text: '', isMe: true,
          fileName: '📤 $filename (${_formatFileSize(fileSize)})',
          fileSize: fileSize, offerId: offerId,
        ));
      });
      _scrollToBottom();
    } else {
      // Small file: auto-send immediately
      setState(() {
        _messages.add(ChatMessage(
          sender: senderName, text: '', isMe: true,
          filePath: file.path,
          fileName: '📤 $filename (${_formatFileSize(fileSize)})',
        ));
      });
      _scrollToBottom();

      final manager = ref.read(fileTransferProvider);
      final payloads = await manager.splitFileIntoChunks(file, senderName);

      for (var payload in payloads) {
        if (widget.isHost) {
          ref.read(webSocketServerProvider).broadcastMessage(payload);
        } else {
          ref.read(webSocketClientProvider).sendMessage(payload);
        }
      }
    }
  }

  void _acceptFileOffer(String offerId) {
    _acceptedOffers.add(offerId);

    final acceptPayload = jsonEncode({
      'type': 'accept_file',
      'offer_id': offerId,
    });

    if (widget.isHost) {
      ref.read(webSocketServerProvider).broadcastMessage(acceptPayload);
    } else {
      ref.read(webSocketClientProvider).sendMessage(acceptPayload);
    }

    setState(() {
      final idx = _messages.indexWhere((m) => m.offerId == offerId && !m.isMe);
      if (idx != -1) {
        final old = _messages[idx];
        _messages[idx] = ChatMessage(
          sender: old.sender, text: '', isMe: false,
          fileName: old.fileName, fileSize: old.fileSize,
          offerId: offerId, isDownloading: true,
        );
      }
    });
  }

  void _cancelFileOffer(String offerId) {
    _cancelledOffers.add(offerId);
    _pendingFileOffers.remove(offerId);
    _downloadProgress.remove(offerId);

    final cancelPayload = jsonEncode({
      'type': 'cancel_file',
      'offer_id': offerId,
    });

    if (widget.isHost) {
      ref.read(webSocketServerProvider).broadcastMessage(cancelPayload);
    } else {
      ref.read(webSocketClientProvider).sendMessage(cancelPayload);
    }

    setState(() {
      for (int i = 0; i < _messages.length; i++) {
        if (_messages[i].offerId == offerId) {
          final old = _messages[i];
          _messages[i] = ChatMessage(
            sender: old.sender, text: '', isMe: old.isMe,
            fileName: old.fileName, fileSize: old.fileSize,
            offerId: offerId, isCancelled: true,
          );
        }
      }
    });
  }

  Future<void> _syncClipboard() async {
    if (!_hasParticipants) {
      _showNoParticipantsWarning();
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final senderName = ref.read(usernameProvider);
      final text = data.text!;

      setState(() {
        _messages.add(ChatMessage(sender: senderName, text: "📋 Splashed Clipboard:\n$text", isMe: true));
      });
      _scrollToBottom();

      final payload = jsonEncode({'type': 'clipboard', 'sender': senderName, 'text': text});

      if (widget.isHost) {
        ref.read(webSocketServerProvider).broadcastMessage(payload);
      } else {
        ref.read(webSocketClientProvider).sendMessage(payload);
      }
    }
  }

  Future<void> _startRecording() async {
    if (!_hasParticipants) {
      _showNoParticipantsWarning();
      return;
    }
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath = p.join(dir.path, 'LANLine_Memo_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint("Recording failed: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        final file = File(path);
        await _sendFile(file);
      }
    } catch (e) {
      debugPrint("Stop recording failed: $e");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    if (!_hasParticipants) {
      _showNoParticipantsWarning();
      return;
    }
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      await _sendFile(file);
    }
  }

  void _sendTypingStatus() {
    final name = ref.read(usernameProvider);
    final payload = jsonEncode({'type': 'typing', 'sender': name});

    if (widget.isHost) {
      ref.read(webSocketServerProvider).broadcastMessage(payload);
    } else {
      ref.read(webSocketClientProvider).sendMessage(payload);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _openFile(String path) async {
    final mimeType = _getMimeType(path);
    await OpenFilex.open(path, type: mimeType);
  }

  String? _getMimeType(String path) {
    final ext = p.extension(path).toLowerCase();
    const mimeMap = {
      '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
      '.gif': 'image/gif', '.webp': 'image/webp', '.bmp': 'image/bmp', '.svg': 'image/svg+xml',
      '.mp4': 'video/mp4', '.mkv': 'video/x-matroska', '.avi': 'video/x-msvideo',
      '.mov': 'video/quicktime', '.webm': 'video/webm',
      '.mp3': 'audio/mpeg', '.m4a': 'audio/mp4', '.wav': 'audio/wav',
      '.ogg': 'audio/ogg', '.flac': 'audio/flac', '.aac': 'audio/aac',
      '.pdf': 'application/pdf', '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain', '.csv': 'text/csv', '.json': 'application/json',
      '.zip': 'application/zip', '.rar': 'application/x-rar-compressed',
      '.7z': 'application/x-7z-compressed', '.tar': 'application/x-tar',
      '.gz': 'application/gzip',
      '.apk': 'application/vnd.android.package-archive',
    };
    return mimeMap[ext];
  }

  void _openFolder(String path) async {
    final dir = p.dirname(path);
    if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dir]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dir]);
    }
  }

  void _shareFile(String path) async {
    final file = XFile(path);
    await SharePlus.instance.share(ShareParams(files: [file]));
  }

  void _showRoomInfoPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(widget.room.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              _infoTile(Icons.wifi, 'Connection',
                  widget.isHost ? 'Host • ${_localIp ?? "Loading..."} : 55556' : 'Client • Connected'),
              _infoTile(
                widget.room.e2eeEnabled ? Icons.lock : Icons.lock_open, 'Encryption',
                widget.room.e2eeEnabled ? 'End-to-End Encrypted (AES-256)' : 'No encryption',
                iconColor: widget.room.e2eeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              _infoTile(Icons.person, 'Display Name', ref.read(usernameProvider)),
              _infoTile(Icons.people, 'Participants', '${_participantCount + 1} (including you)',
                  iconColor: _hasParticipants ? Colors.blueAccent : Colors.orangeAccent),
              if (widget.isHost && _localIp != null) ...[
                const SizedBox(height: 20),
                const Text('Share this room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Others can scan this QR code to join:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: QrImageView(
                      data: jsonEncode({'ip': _localIp, 'e2ee': widget.room.e2eeEnabled, 'room': widget.room.name}),
                      version: QrVersions.auto, size: 180.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text('IP: $_localIp', style: const TextStyle(color: Colors.grey, fontSize: 13))),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, {Color iconColor = Colors.blueAccent}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragDone: (detail) {
        final files = detail.files.map((e) => File(e.path)).toList();
        _handleDroppedFiles(files);
      },
      onDragEntered: (detail) => setState(() => _isDragging = true),
      onDragExited: (detail) => setState(() => _isDragging = false),
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.room.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Row(
                children: [
                  if (widget.room.e2eeEnabled)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.lock, size: 11, color: Colors.greenAccent),
                    ),
                  Text(
                    _hasParticipants
                        ? '${_participantCount + 1} participants'
                        : 'Waiting for participants...',
                    style: TextStyle(
                      fontSize: 12,
                      color: _hasParticipants ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          backgroundColor: const Color(0xFF252525),
          elevation: 4,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white70),
              tooltip: 'Room Info',
              onPressed: _showRoomInfoPanel,
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
                ),
                if (_typingUsers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 24.0, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_typingUsers.join(", ")} ${_typingUsers.length > 1 ? "are" : "is"} typing...',
                        style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ),
                  ),
                _buildMessageInput(),
              ],
            ),
            if (_isDragging)
              Container(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                child: const Center(
                  child: Text(
                    'Drop files here to send!',
                    style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!msg.isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(msg.sender, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
          if (msg.isMe && msg.id != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Icon(Icons.done_all, size: 16, color: msg.isAcked ? Colors.blueAccent : Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage msg) {
    if (msg.filePath != null || msg.offerId != null) {
      return _buildFileBubble(msg);
    }
    if (msg.text.contains('.m4a') && msg.text.contains('Saved to: ')) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
          onPressed: () {
            final pathMatch = msg.text.split('Saved to: ');
            if (pathMatch.length == 2) _audioPlayer.play(DeviceFileSource(pathMatch[1].trim()));
          },
        ),
        const Expanded(child: Text("🎵 Voice Memo Received", style: TextStyle(color: Colors.white, fontSize: 14))),
      ]);
    }
    if (msg.text.contains('.m4a') && msg.text.startsWith('🎤 Sent Voi')) {
      return const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.audiotrack, color: Colors.white, size: 30),
        SizedBox(width: 8),
        Text("🎵 Audio message sent", style: TextStyle(color: Colors.white)),
      ]);
    }
    return Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15));
  }

  Widget _buildFileBubble(ChatMessage msg) {
    final fileName = msg.fileName ?? (msg.filePath != null ? p.basename(msg.filePath!) : 'Unknown file');
    final isCompleted = msg.filePath != null;
    final isOffer = msg.offerId != null && !isCompleted;
    final isAudio = msg.filePath != null &&
        (msg.filePath!.endsWith('.m4a') || msg.filePath!.endsWith('.mp3') || msg.filePath!.endsWith('.wav'));
    final icon = isAudio ? Icons.audiotrack : Icons.insert_drive_file;

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
                  Text(fileName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis, maxLines: 2,
                  ),
                  if (msg.fileSize != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(_formatFileSize(msg.fileSize!), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
        ),

        // Cancelled
        if (msg.isCancelled) ...[
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cancel, color: Colors.redAccent.withValues(alpha: 0.7), size: 16),
            const SizedBox(width: 6),
            Text('Cancelled', style: TextStyle(color: Colors.redAccent.withValues(alpha: 0.7), fontSize: 12)),
          ]),
        ],

        // Pending offer — Download button (receiver only)
        if (isOffer && !msg.isMe && !msg.isDownloading && !msg.isCancelled) ...[
          const SizedBox(height: 10),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _fileActionButton(Icons.download, 'Download', () => _acceptFileOffer(msg.offerId!)),
          ]),
        ],

        // Downloading — progress bar + cancel
        if (msg.isDownloading && !msg.isCancelled) ...[
          const SizedBox(height: 10),
          Builder(builder: (_) {
            final progress = _downloadProgress[msg.offerId];
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
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    if (msg.fileSize != null) ...[
                      const SizedBox(width: 6),
                      Text('${_formatFileSize((pct * msg.fileSize!).round())} / ${_formatFileSize(msg.fileSize!)}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                    const Spacer(),
                    InkWell(
                      onTap: () => _cancelFileOffer(msg.offerId!),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.close, color: Colors.redAccent, size: 14),
                          SizedBox(width: 4),
                          Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],

        // Sender: waiting for download + cancel, or downloaded status
        if (isOffer && msg.isMe && !msg.isCancelled) ...[
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('⏳ Waiting for download', style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _cancelFileOffer(msg.offerId!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.close, color: Colors.redAccent, size: 14),
                  SizedBox(width: 4),
                  Text('Cancel', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
        ],

        // Sender: file was downloaded by someone (isCompleted && isMe && had offer)
        if (isCompleted && msg.isMe && msg.offerId != null && !msg.isCancelled) ...[
          const SizedBox(height: 8),
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
            SizedBox(width: 6),
            Text('Downloaded', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
          ]),
        ],

        // Completed file: Open/Folder/Play buttons (receiver side)
        if (isCompleted && !msg.isMe) ...[
          const SizedBox(height: 10),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (isAudio)
              _fileActionButton(Icons.play_arrow, 'Play', () {
                _audioPlayer.play(DeviceFileSource(msg.filePath!));
              }),
            _fileActionButton(Icons.open_in_new, 'Open', () => _openFile(msg.filePath!)),
            const SizedBox(width: 8),
            if (Platform.isAndroid)
              _fileActionButton(Icons.share, 'Share', () => _shareFile(msg.filePath!))
            else
              _fileActionButton(Icons.folder_open, 'Folder', () => _openFolder(msg.filePath!)),
          ]),
        ],
      ],
    );
  }

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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final disabledColor = Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF252525),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.attach_file, color: _hasParticipants ? Colors.blueAccent : disabledColor),
              onPressed: _pickAndSendFile,
            ),
            IconButton(
              icon: Icon(Icons.content_paste, color: _hasParticipants ? Colors.greenAccent : disabledColor),
              tooltip: "Sync Clipboard",
              onPressed: _syncClipboard,
            ),
            GestureDetector(
              onTap: () {
                if (!_hasParticipants) {
                  _showNoParticipantsWarning();
                  return;
                }
                _showTopSnackBar('Hold down the mic continuously to record!');
              },
              onLongPress: _startRecording,
              onLongPressUp: _stopRecording,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.mic, color: _isRecording ? Colors.redAccent : (_hasParticipants ? Colors.orangeAccent : disabledColor)),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => _sendTypingStatus(),
                decoration: InputDecoration(
                  hintText: _hasParticipants ? 'Type a message...' : 'Waiting for someone to join...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFF333333),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: _hasParticipants ? Colors.blueAccent : disabledColor,
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
