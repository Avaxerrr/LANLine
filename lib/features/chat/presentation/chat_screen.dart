import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/models/room_model.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/providers/file_transfer_notifier.dart';
import '../../../core/providers/call_notifier.dart';
import '../../../core/network/websocket_server.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/network/discovery_service.dart';
import '../../../core/providers/username_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../call/presentation/call_screen.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_room_info_panel.dart';

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

  bool _isDragging = false;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final _ringtonePlayer = AudioPlayer();
  final _notificationPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _localIp;
  final FocusNode _textFocusNode = FocusNode();
  final Set<int> _expandedTimestamps = {};

  // Bridge getters — read from ChatNotifier state
  int get _participantCount => ref.read(chatProvider).participantCount;
  List<String> get _participantNames => ref.read(chatProvider).participantNames;
  bool get _roomClosed => ref.read(chatProvider).roomClosed;


  StreamSubscription? _messageSubscription;

  bool get _hasParticipants => _participantCount > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocalIp();
    NotificationService().initialize();

    // Initialize the chat notifier after the first frame to avoid
    // modifying provider state during a widget lifecycle method.
    Future.microtask(() {
      final notifier = ref.read(chatProvider.notifier);
      notifier.init(
        ChatConfig(isHost: widget.isHost, roomName: widget.room.name),
      );
      // Register callback for room closed (needs BuildContext for dialog)
      notifier.onRoomClosed = () {
        if (mounted) _handleRoomClosed();
      };

      ref.read(fileTransferNotifierProvider.notifier).init(
        FileTransferConfig(roomName: widget.room.name),
      );

      // Register callback for incoming calls (needs BuildContext for dialog)
      ref.read(callNotifierProvider.notifier).onIncomingCall = (info) {
        if (mounted) _showIncomingCallDialog(info);
      };
    });

    final stream = widget.isHost
        ? ref.read(webSocketServerProvider).onMessageReceived
        : ref.read(webSocketClientProvider).onMessageReceived;

    _messageSubscription = stream.listen((message) {
      if (mounted) {
        _handleIncomingMessage(message);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    NotificationService().appInForeground = state == AppLifecycleState.resumed;
  }

  Future<void> _loadLocalIp() async {
    // If a specific bind address was chosen (e.g. Tailscale), use that
    // instead of auto-detecting — the server is bound to that IP.
    if (widget.room.bindAddress != null) {
      if (mounted) setState(() => _localIp = widget.room.bindAddress);
      return;
    }
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
    // Route through notifier first — it handles message, ack, typing,
    // participant_list, room_closed, error, call_summary, clipboard.
    final handledType = ref.read(chatProvider.notifier).handleIncomingMessage(rawMessage);

    if (handledType != null) {
      // Notifier handled it. Perform UI side-effects based on type.
      switch (handledType) {
        case 'message':
          final data = jsonDecode(rawMessage);
          final sender = data['sender'] as String;
          final text = data['text'] as String;
          _scrollToBottom();
          _notificationPlayer.play(AssetSource('audio/notification.mp3'));
          NotificationService().showMessageNotification(
            sender: sender,
            message: text,
            roomName: widget.room.name,
          );
          break;
        case 'room_closed':
          _handleRoomClosed();
          break;
        case 'clipboard':
          final data = jsonDecode(rawMessage);
          final text = data['text'] as String;
          await Clipboard.setData(ClipboardData(text: text));
          _scrollToBottom();
          break;
        case 'error':
        case 'call_summary':
          _scrollToBottom();
          break;
      }
      return;
    }

    // Notifier returned null — try call types, then file types.
    // Call signaling
    final callResult = ref.read(callNotifierProvider.notifier).handleCallMessage(rawMessage);
    if (callResult != null) {
      switch (callResult) {
        case 'call_decline':
          final data = jsonDecode(rawMessage);
          final sender = data['sender'] as String;
          if (sender != ref.read(usernameProvider)) {
            _showTopSnackBar('$sender declined the call');
          }
          break;
        case 'call_busy':
          final data = jsonDecode(rawMessage);
          final sender = data['sender'] as String;
          if (sender != ref.read(usernameProvider)) {
            _showTopSnackBar('$sender is on another call');
          }
          break;
      }
      return;
    }

    // File types — delegate to FileTransferNotifier
    try {
      final fileResult = await ref.read(fileTransferNotifierProvider.notifier)
          .handleFileMessage(rawMessage);
      if (fileResult != null) {
        switch (fileResult) {
          case 'file_received':
            final fileData = jsonDecode(rawMessage);
            final sender = fileData['sender'] as String;
            final filename = fileData['filename'] as String;
            _scrollToBottom();
            _notificationPlayer.play(AssetSource('audio/notification.mp3'));
            NotificationService().showFileNotification(sender: sender, fileName: filename);
            break;
          case 'file_offer':
            final fileData = jsonDecode(rawMessage);
            final sender = fileData['sender'] as String;
            final filename = fileData['filename'] as String;
            final fileSize = fileData['size'] as int;
            _scrollToBottom();
            _notificationPlayer.play(AssetSource('audio/notification.mp3'));
            NotificationService().showFileNotification(
              sender: sender, fileName: '$filename (${formatFileSize(fileSize)})', isOffer: true,
            );
            break;
          case 'file_downloaded':
            final fileData = jsonDecode(rawMessage);
            final downloader = fileData['downloader'] as String? ?? 'Someone';
            _showTopSnackBar('✅ $downloader downloaded the file');
            break;
        }
      }
    } catch (e) {
      debugPrint('Error handling file message: $e');
    }
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

    // Notifier handles payload construction, WebSocket send, and state update
    final sent = ref.read(chatProvider.notifier).sendMessage(text);
    if (sent) {
      _textController.clear();
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    ref.read(fileTransferNotifierProvider.notifier).dispose();
    ref.read(callNotifierProvider.notifier).dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _ringtonePlayer.dispose();
    _notificationPlayer.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _textFocusNode.dispose();

    ref.read(chatProvider.notifier).dispose();

    if (widget.isHost) {
      ref.read(discoveryServiceProvider).stop();
      ref.read(webSocketServerProvider).stopServer();
    } else {
      ref.read(webSocketClientProvider).disconnect();
    }
    super.dispose();
  }

  void _handleRoomClosed() {
    if (_roomClosed) return;
    // markRoomClosed is called by the notifier before invoking this callback,
    // but also called here for the room_closed message path from handleIncomingMessage.
    ref.read(chatProvider.notifier).markRoomClosed();

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

  // ─── Call Handling (UI only — signaling is in CallNotifier) ───

  static const _proximityChannel = MethodChannel('com.lanline.lanline/proximity');

  void _openCallScreen({
    required String callId,
    required String myName,
    required String callType,
    required bool isInitiator,
  }) async {
    final callNotifier = ref.read(callNotifierProvider.notifier);
    final result = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: callId,
          myName: myName,
          callType: callType,
          isInitiator: isInitiator,
          sendSignal: callNotifier.sendCallSignal,
        ),
      ),
    );

    if (result != null && result > 0 && mounted) {
      callNotifier.addCallSummary(
        myName: myName,
        callType: callType,
        durationSeconds: result,
      );
      _scrollToBottom();
    }
  }

  void _showIncomingCallDialog(IncomingCallInfo info) {
    _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
    _ringtonePlayer.play(AssetSource('audio/ringtone.mp3'));
    if (Platform.isAndroid) {
      try { _proximityChannel.invokeMethod('startRingtone'); } catch (_) {}
    }

    final callNotifier = ref.read(callNotifierProvider.notifier);

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
                info.callType == 'video' ? Icons.videocam : Icons.call,
                size: 36, color: Colors.greenAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              info.callType == 'video' ? 'Incoming Video Call' : 'Incoming Call',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ],
        ),
        content: Text(
          '${info.sender} is calling...',
          style: const TextStyle(color: Colors.grey, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          // Decline
          GestureDetector(
            onTap: () {
              _ringtonePlayer.stop();
              if (Platform.isAndroid) {
                try { _proximityChannel.invokeMethod('stopRingtone'); } catch (_) {}
              }
              callNotifier.sendCallSignal(jsonEncode({
                'type': 'call_decline',
                'callId': info.callId,
                'sender': info.myName,
              }));
              Navigator.pop(ctx);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
                  child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 6),
                const Text('Decline', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
              ],
            ),
          ),
          // Accept
          GestureDetector(
            onTap: () {
              _ringtonePlayer.stop();
              if (Platform.isAndroid) {
                try { _proximityChannel.invokeMethod('stopRingtone'); } catch (_) {}
              }
              Navigator.pop(ctx);
              _openCallScreen(callId: info.callId, myName: info.myName, callType: info.callType, isInitiator: false);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent),
                  child: Icon(info.callType == 'video' ? Icons.videocam : Icons.call, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 6),
                const Text('Accept', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
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
    await ref.read(fileTransferNotifierProvider.notifier).sendFile(file);
    _scrollToBottom();
  }

  void _acceptFileOffer(String offerId) {
    ref.read(fileTransferNotifierProvider.notifier).acceptFileOffer(offerId);
  }

  void _cancelFileOffer(String offerId) {
    ref.read(fileTransferNotifierProvider.notifier).cancelFileOffer(offerId);
  }

  Future<void> _syncClipboard() async {
    if (!_hasParticipants) {
      _showNoParticipantsWarning();
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      final result = ref.read(chatProvider.notifier).sendClipboard(data.text!);
      if (result != null) {
        _scrollToBottom();
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
    ref.read(chatProvider.notifier).sendTypingStatus();
  }

  void _showRoomInfoPanel() {
    showRoomInfoPanel(
      context: context,
      room: widget.room,
      isHost: widget.isHost,
      myName: ref.read(usernameProvider),
      localIp: _localIp,
      participantCount: _participantCount,
      participantNames: _participantNames,
      hasParticipants: _hasParticipants,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch chat state so widget rebuilds on message/participant/typing changes
    final chatState = ref.watch(chatProvider);
    final fileTransferState = ref.watch(fileTransferNotifierProvider);
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
                    chatState.hasParticipants
                        ? '${chatState.participantCount + 1} participants'
                        : 'Waiting for participants...',
                    style: TextStyle(
                      fontSize: 12,
                      color: chatState.hasParticipants ? Colors.greenAccent : Colors.orangeAccent,
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
              onPressed: _hasParticipants
                  ? () {
                      final name = ref.read(usernameProvider);
                      final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
                      _openCallScreen(callId: callId, myName: name, callType: 'audio', isInitiator: true);
                    }
                  : () => _showTopSnackBar('No one else is in the room'),
            ),
            // Video call button
            IconButton(
              icon: const Icon(Icons.videocam, color: Colors.blueAccent),
              tooltip: 'Video Call',
              onPressed: _hasParticipants
                  ? () {
                      final name = ref.read(usernameProvider);
                      final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
                      _openCallScreen(callId: callId, myName: name, callType: 'video', isInitiator: true);
                    }
                  : () => _showTopSnackBar('No one else is in the room'),
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
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      return ChatMessageBubble(
                        msg: chatState.messages[index],
                        index: index,
                        messages: chatState.messages,
                        expandedTimestamps: _expandedTimestamps,
                        downloadProgress: fileTransferState.downloadProgress,
                        audioPlayer: _audioPlayer,
                        onAcceptFile: _acceptFileOffer,
                        onCancelFile: _cancelFileOffer,
                        onToggleTimestamp: (i) {
                          setState(() {
                            if (_expandedTimestamps.contains(i)) {
                              _expandedTimestamps.remove(i);
                            } else {
                              _expandedTimestamps.add(i);
                            }
                          });
                        },
                        onShowSnackBar: _showTopSnackBar,
                      );
                    },
                  ),
                ),
                if (chatState.typingUsers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 24.0, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${chatState.typingUsers.join(", ")} ${chatState.typingUsers.length > 1 ? "are" : "is"} typing...',
                        style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
                      ),
                    ),
                  ),
                ChatInputBar(
                  textController: _textController,
                  textFocusNode: _textFocusNode,
                  hasParticipants: _hasParticipants,
                  isRecording: _isRecording,
                  onSendMessage: _sendMessage,
                  onSendTypingStatus: _sendTypingStatus,
                  onSyncClipboard: _syncClipboard,
                  onShowAttachmentMenu: _showAttachmentMenu,
                  onShowNoParticipantsWarning: _showNoParticipantsWarning,
                ),
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


  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AttachmentMenu(
        isRecording: _isRecording,
        onPickFile: _pickAndSendFile,
        onPickFromGallery: _pickFromGallery,
        onTakePhoto: _takePhoto,
        onSyncClipboard: _syncClipboard,
        onStartRecording: _startRecording,
        onStopRecording: _stopRecording,
      ),
    );
  }
}
