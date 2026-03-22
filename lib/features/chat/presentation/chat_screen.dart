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
import 'package:image_picker/image_picker.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/room_model.dart';
import '../../../core/network/websocket_server.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/network/discovery_service.dart';
import '../../../core/network/webrtc_call_service.dart';
import '../../../core/providers/username_provider.dart';
import '../../../core/network/file_transfer_manager.dart';
import '../../../core/providers/download_history_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../call/presentation/call_screen.dart';
import 'package:share_plus/share_plus.dart';

// Regex to detect emoji-only messages (1-3 emojis, no other text)
final _emojiOnlyRegex = RegExp(
  r'^(\p{Emoji_Presentation}|\p{Emoji}\uFE0F|[\u200D\uFE0F]){1,3}$',
  unicode: true,
);

bool _isEmojiOnly(String text) => _emojiOnlyRegex.hasMatch(text.trim());

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'};

bool _isImageFile(String? path) {
  if (path == null) return false;
  final ext = p.extension(path).toLowerCase();
  return _imageExtensions.contains(ext);
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
  List<String> _participantNames = [];
  final FocusNode _textFocusNode = FocusNode();
  final Set<int> _expandedTimestamps = {};
  bool _roomClosed = false;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _participantSubscription;

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

    _messageSubscription = stream.listen((message) {
      if (mounted) {
        _handleIncomingMessage(message);
      }
    });

    // Host tracks participant count from the server directly
    if (widget.isHost) {
      _participantSubscription = ref.read(webSocketServerProvider).onParticipantCountChanged.listen((count) {
        if (mounted) {
          setState(() {
            _participantCount = count;
            _participantNames = ref.read(webSocketServerProvider).participantNames;
          });
        }
      });
    } else {
      // Client: listen for host disconnect
      ref.read(webSocketClientProvider).onDisconnected = () {
        if (mounted && !_roomClosed) {
          _handleRoomClosed();
        }
      };
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
      } else if (data['type'] == 'participant_list') {
        if (!widget.isHost) {
          final count = data['count'] as int;
          final names = (data['names'] as List<dynamic>?)?.cast<String>() ?? [];
          setState(() {
            _participantCount = count - 1;
            _participantNames = names;
          });
        }
      } else if (data['type'] == 'room_closed') {
        if (!widget.isHost && !_roomClosed) {
          _handleRoomClosed();
        }
      } else if (data['type'] == 'call_start') {
        _handleIncomingCall(data);
      } else if (data['type'] == 'call_join') {
        _handleCallJoin(data);
      } else if (data['type'] == 'call_offer') {
        _handleCallOffer(data);
      } else if (data['type'] == 'call_answer') {
        _handleCallAnswer(data);
      } else if (data['type'] == 'ice_candidate') {
        _handleIceCandidate(data);
      } else if (data['type'] == 'call_leave' || data['type'] == 'call_end') {
        _handleCallEnd(data);
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
    _messageSubscription?.cancel();
    _participantSubscription?.cancel();
    _progressThrottleTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();

    if (widget.isHost) {
      ref.read(discoveryServiceProvider).stop();
      ref.read(webSocketServerProvider).stopServer();
    } else {
      ref.read(webSocketClientProvider).onDisconnected = null;
      ref.read(webSocketClientProvider).disconnect();
    }
    super.dispose();
  }

  void _handleRoomClosed() {
    if (_roomClosed) return;
    _roomClosed = true;

    ref.read(webSocketClientProvider).onDisconnected = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252525),
        title: const Row(children: [
          Icon(Icons.info_outline, color: Colors.orangeAccent),
          SizedBox(width: 10),
          Text('Room Closed', style: TextStyle(color: Colors.white)),
        ]),
        content: const Text(
          'The host has closed this room.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // go back to join room
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─── Call Handling ─────────────────────────────────────────────

  void _sendCallSignal(String message) {
    if (widget.isHost) {
      ref.read(webSocketServerProvider).broadcastMessage(message);
    } else {
      ref.read(webSocketClientProvider).sendMessage(message);
    }
  }

  void _startAudioCall() {
    final name = ref.read(usernameProvider);
    final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
    _openCallScreen(callId: callId, myName: name, callType: 'audio', isInitiator: true);
  }

  void _openCallScreen({
    required String callId,
    required String myName,
    required String callType,
    required bool isInitiator,
  }) async {
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          myName: myName,
          callType: callType,
          isInitiator: isInitiator,
          sendSignal: _sendCallSignal,
        ),
      ),
    );

    // Add call summary bubble to chat
    if (result != null && result > 0 && mounted) {
      final m = (result ~/ 60).toString().padLeft(2, '0');
      final s = (result % 60).toString().padLeft(2, '0');
      final icon = callType == 'video' ? '📹' : '📞';
      final label = callType == 'video' ? 'Video call' : 'Voice call';
      setState(() {
        _messages.add(ChatMessage(
          sender: myName,
          text: '$icon $label • $m:$s',
          isMe: true,
        ));
      });
      _scrollToBottom();
    }
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final callId = data['callId'] as String;
    final callType = (data['callType'] as String?) ?? 'audio';
    final myName = ref.read(usernameProvider);

    // Don't show incoming call to the person who started it
    if (sender == myName) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.greenAccent.withValues(alpha: 0.15),
              ),
              child: Icon(
                callType == 'video' ? Icons.videocam : Icons.call,
                size: 36, color: Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Incoming Call', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: Text(
          '$sender is calling...',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          // Decline
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
              child: const Icon(Icons.call_end, color: Colors.white, size: 28),
            ),
          ),
          // Accept
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              _openCallScreen(callId: callId, myName: myName, callType: callType, isInitiator: false);
            },
            child: Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent),
              child: const Icon(Icons.call, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCallJoin(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final myName = ref.read(usernameProvider);
    if (sender == myName) return;

    final callService = ref.read(webRtcCallServiceProvider);
    if (callService.state == CallState.inCall) {
      callService.callParticipants.add(sender);
      callService.onParticipantChanged?.call(sender, true);
      // I create offer to the new joiner
      callService.setupPeerConnection(sender, myName, makeOffer: true);
    }
  }

  void _handleCallOffer(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final target = data['target'] as String;
    final myName = ref.read(usernameProvider);
    if (target != myName) return;

    final callService = ref.read(webRtcCallServiceProvider);
    callService.handleOffer(sender, myName, data['sdp'] as Map<String, dynamic>);
  }

  void _handleCallAnswer(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final target = data['target'] as String;
    final myName = ref.read(usernameProvider);
    if (target != myName) return;

    final callService = ref.read(webRtcCallServiceProvider);
    callService.handleAnswer(sender, data['sdp'] as Map<String, dynamic>);
  }

  void _handleIceCandidate(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final target = data['target'] as String;
    final myName = ref.read(usernameProvider);
    if (target != myName) return;

    final callService = ref.read(webRtcCallServiceProvider);
    callService.handleIceCandidate(sender, data['candidate'] as Map<String, dynamic>);
  }

  void _handleCallEnd(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final callService = ref.read(webRtcCallServiceProvider);

    if (data['type'] == 'call_end') {
      // Entire call ended
      callService.handleParticipantLeft(sender);
    } else {
      // Single participant left
      callService.handleParticipantLeft(sender);
    }
  }

  // ─── End Call Handling ─────────────────────────────────────────

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

  Future<void> _pickFromGallery() async {
    if (!_hasParticipants) {
      _showNoParticipantsWarning();
      return;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await _sendFile(File(image.path));
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'],
      );
      if (result != null && result.files.single.path != null) {
        await _sendFile(File(result.files.single.path!));
      }
    }
  }

  Future<void> _takePhoto() async {
    if (!_hasParticipants) {
      _showNoParticipantsWarning();
      return;
    }
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      await _sendFile(File(image.path));
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
    final myName = ref.read(usernameProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
                  widget.isHost ? 'Host • ${_localIp ?? "Loading..."} : ${widget.room.port}' : 'Client • Connected'),
              _infoTile(
                widget.room.e2eeEnabled ? Icons.lock : Icons.lock_open, 'Encryption',
                widget.room.e2eeEnabled ? 'End-to-End Encrypted (AES-256)' : 'No encryption',
                iconColor: widget.room.e2eeEnabled ? Colors.greenAccent : Colors.grey,
              ),
              _infoTile(Icons.person, 'Display Name', myName),
              _infoTile(Icons.people, 'Participants', '${_participantCount + 1} (including you)',
                  iconColor: _hasParticipants ? Colors.blueAccent : Colors.orangeAccent),

              // Participant list
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Always show self
                    _participantRow(myName, isYou: true),
                    // Show connected participants
                    ..._participantNames.map((name) => _participantRow(name)),
                    if (!_hasParticipants)
                      const Padding(
                        padding: EdgeInsets.only(left: 44, top: 4),
                        child: Text('No one else is here yet...', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                      ),
                  ],
                ),
              ),

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
                      data: jsonEncode({
                        'ip': _localIp,
                        'e2ee': widget.room.e2eeEnabled,
                        'room': widget.room.name,
                        'port': widget.room.port,
                      }),
                      version: QrVersions.auto, size: 180.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: Text('IP: $_localIp:${widget.room.port}', style: const TextStyle(color: Colors.grey, fontSize: 13))),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _participantRow(String name, {bool isYou = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            isYou ? '$name (You)' : name,
            style: TextStyle(color: isYou ? Colors.white70 : Colors.white, fontSize: 14),
          ),
        ],
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
            // Audio call button
            IconButton(
              icon: const Icon(Icons.call, color: Colors.greenAccent),
              tooltip: 'Audio Call',
              onPressed: _hasParticipants ? _startAudioCall : () => _showTopSnackBar('No one else is in the room'),
            ),
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
                      return _buildMessageBubble(_messages[index], index);
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

  String _formatTimestamp(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  void _showMessageOptions(ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (msg.text.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.blueAccent),
                  title: const Text('Copy Text', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.text));
                    Navigator.pop(ctx);
                    _showTopSnackBar('Copied to clipboard');
                  },
                ),
              if (msg.filePath != null)
                ListTile(
                  leading: const Icon(Icons.open_in_new, color: Colors.orangeAccent),
                  title: const Text('Open File', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openFile(msg.filePath!);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, int index) {
    // Message grouping: hide sender if same sender as previous message
    final bool showSender;
    if (msg.isMe) {
      showSender = false;
    } else if (index == 0) {
      showSender = true;
    } else {
      final prev = _messages[index - 1];
      showSender = prev.sender != msg.sender || prev.isMe != msg.isMe;
    }

    // Reduce spacing for grouped messages
    final bottomPadding = (!msg.isMe && index < _messages.length - 1 &&
        _messages[index + 1].sender == msg.sender && !_messages[index + 1].isMe)
        ? 4.0 : 14.0;

    // Only show timestamp on the last message, or when explicitly tapped
    final isLastMessage = index == _messages.length - 1;
    final showTimestamp = isLastMessage || _expandedTimestamps.contains(index);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(msg.sender, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          GestureDetector(
            onLongPress: () => _showMessageOptions(msg),
            onTap: isLastMessage ? null : () {
              setState(() {
                if (_expandedTimestamps.contains(index)) {
                  _expandedTimestamps.remove(index);
                } else {
                  _expandedTimestamps.add(index);
                }
              });
            },
            child: Container(
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
          ),
          // Timestamp + read receipt — animated slide
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: showTimestamp
                ? Padding(
                    padding: const EdgeInsets.only(top: 3, left: 12, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTimestamp(msg.timestamp),
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                        if (msg.isMe && msg.id != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 14, color: msg.isAcked ? Colors.blueAccent : Colors.grey),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
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

    // Emoji-only: render large
    if (_isEmojiOnly(msg.text)) {
      return Text(msg.text, style: const TextStyle(fontSize: 42));
    }

    // Linkified text with clickable URLs
    return Linkify(
      text: msg.text,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      linkStyle: const TextStyle(color: Colors.lightBlueAccent, decoration: TextDecoration.underline, fontSize: 15),
      onOpen: (link) async {
        final uri = Uri.tryParse(link.url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  Widget _buildFileBubble(ChatMessage msg) {
    final fileName = msg.fileName ?? (msg.filePath != null ? p.basename(msg.filePath!) : 'Unknown file');
    final isCompleted = msg.filePath != null;
    final isOffer = msg.offerId != null && !isCompleted;
    final isAudio = msg.filePath != null &&
        (msg.filePath!.endsWith('.m4a') || msg.filePath!.endsWith('.mp3') || msg.filePath!.endsWith('.wav'));
    final isImage = _isImageFile(msg.filePath);
    final icon = isAudio ? Icons.audiotrack : (isImage ? Icons.image : Icons.insert_drive_file);

    // Show inline image preview for completed image files
    if (isCompleted && isImage && !msg.isMe) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: Image.file(
                File(msg.filePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.broken_image, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(fileName, style: const TextStyle(color: Colors.white)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _fileActionButton(Icons.open_in_new, 'Open', () => _openFile(msg.filePath!)),
            const SizedBox(width: 8),
            if (Platform.isAndroid)
              _fileActionButton(Icons.share, 'Share', () => _shareFile(msg.filePath!))
            else
              _fileActionButton(Icons.folder_open, 'Folder', () => _openFolder(msg.filePath!)),
          ]),
        ],
      );
    }

    // Sender's own image preview
    if (isCompleted && isImage && msg.isMe) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: Image.file(
                File(msg.filePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.broken_image, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(fileName, style: const TextStyle(color: Colors.white)),
                ]),
              ),
            ),
          ),
          if (msg.offerId != null && !msg.isCancelled) ...[
            const SizedBox(height: 6),
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
              SizedBox(width: 6),
              Text('Downloaded', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            ]),
          ],
        ],
      );
    }

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

  void _showAttachmentMenu() {
    final bool isMobile = Platform.isAndroid || Platform.isIOS;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  _attachmentGridItem(
                    icon: Icons.attach_file,
                    label: 'File',
                    color: Colors.blueAccent,
                    onTap: () { Navigator.pop(ctx); _pickAndSendFile(); },
                  ),
                  _attachmentGridItem(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    color: Colors.purpleAccent,
                    onTap: () { Navigator.pop(ctx); _pickFromGallery(); },
                  ),
                  if (isMobile)
                    _attachmentGridItem(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      color: Colors.orangeAccent,
                      onTap: () { Navigator.pop(ctx); _takePhoto(); },
                    ),
                  _attachmentGridItem(
                    icon: Icons.content_paste,
                    label: 'Clipboard',
                    color: Colors.greenAccent,
                    onTap: () { Navigator.pop(ctx); _syncClipboard(); },
                  ),
                  _attachmentGridItem(
                    icon: _isRecording ? Icons.stop : Icons.mic,
                    label: _isRecording ? 'Stop' : 'Voice Memo',
                    color: _isRecording ? Colors.red : Colors.redAccent,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (_isRecording) {
                        _stopRecording();
                      } else {
                        _startRecording();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentGridItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final disabledColor = Colors.grey.shade700;
    final bool isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF252525),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // "+" menu button
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton(
                icon: Icon(Icons.add_circle_outline, color: _hasParticipants ? Colors.blueAccent : disabledColor, size: 28),
                tooltip: 'Attach',
                onPressed: () {
                  if (!_hasParticipants) {
                    _showNoParticipantsWarning();
                    return;
                  }
                  _showAttachmentMenu();
                },
              ),
            ),
            // Clipboard button (quick access)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton(
                icon: Icon(Icons.content_paste, color: _hasParticipants ? Colors.greenAccent : disabledColor, size: 24),
                tooltip: 'Sync Clipboard',
                onPressed: _syncClipboard,
              ),
            ),
            const SizedBox(width: 4),
            // Expandable text field
            Expanded(
              child: KeyboardListener(
                focusNode: _textFocusNode,
                onKeyEvent: isDesktop ? (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    _sendMessage();
                  }
                } : null,
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white),
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: isDesktop ? TextInputAction.none : TextInputAction.send,
                  onChanged: (_) => _sendTypingStatus(),
                  decoration: InputDecoration(
                    hintText: _hasParticipants ? 'Type a message...' : 'Waiting for someone to join...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF333333),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: isDesktop ? null : (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: CircleAvatar(
                backgroundColor: _hasParticipants ? Colors.blueAccent : disabledColor,
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendMessage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
