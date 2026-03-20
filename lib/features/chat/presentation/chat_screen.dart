import 'dart:convert';
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
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/models/room_model.dart';
import '../../../core/network/websocket_server.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/network/discovery_service.dart';
import '../../../core/providers/username_provider.dart';
import '../../../core/network/file_transfer_manager.dart';

class ChatMessage {
  final String? id;
  final String sender;
  final String text;
  final bool isMe;
  bool isAcked;

  ChatMessage({this.id, required this.sender, required this.text, required this.isMe, this.isAcked = false});
}

class ChatScreen extends ConsumerStatefulWidget {
  final bool isHost;
  final Room room;
  const ChatScreen({super.key, required this.isHost, required this.room});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  final Set<String> _typingUsers = {};
  bool _isDragging = false;
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _loadLocalIp();
    
    final stream = widget.isHost
        ? ref.read(webSocketServerProvider).onMessageReceived
        : ref.read(webSocketClientProvider).onMessageReceived;

    stream.listen((message) {
      if (mounted) {
        _handleIncomingMessage(message);
      }
    });
  }

  Future<void> _loadLocalIp() async {
    final ip = await ref.read(discoveryServiceProvider).getLocalIpAddress();
    if (mounted) setState(() => _localIp = ip);
  }

  void _handleIncomingMessage(String rawMessage) async {
    try {
      final data = jsonDecode(rawMessage);
      if (data['type'] == 'typing') {
        final sender = data['sender'];
        setState(() {
          _typingUsers.add(sender);
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _typingUsers.remove(sender);
            });
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
        
        final ackPayload = jsonEncode({'type': 'ack', 'id': msgId});
        if (widget.isHost) {
          ref.read(webSocketServerProvider).broadcastMessage(ackPayload);
        } else {
          ref.read(webSocketClientProvider).sendMessage(ackPayload);
        }
      } else if (data['type'] == 'file_chunk') {
        final manager = ref.read(fileTransferProvider);
        final completeFile = await manager.handleChunk(data);
        if (completeFile != null) {
          final sender = data['sender'] as String;
          final filename = data['filename'] as String;
          setState(() {
            _messages.add(ChatMessage(sender: sender, text: "📁 Received file: $filename\nSaved to: ${completeFile.path}", isMe: false));
          });
          _scrollToBottom();
        }
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
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _textController.dispose();
    _scrollController.dispose();
    
    // Stop server/broadcasting when leaving (host only)
    if (widget.isHost) {
      ref.read(discoveryServiceProvider).stop();
      ref.read(webSocketServerProvider).stopServer();
    } else {
      ref.read(webSocketClientProvider).disconnect();
    }
    super.dispose();
  }

  Future<void> _handleDroppedFiles(List<File> files) async {
    for (var file in files) {
      final filename = p.basename(file.path);
      final senderName = ref.read(usernameProvider);

      setState(() {
        _messages.add(ChatMessage(sender: senderName, text: "📤 Sending dropped file: $filename...", isMe: true));
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

  Future<void> _syncClipboard() async {
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
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final filePath = p.join(dir.path, 'LANLine_Memo_${DateTime.now().millisecondsSinceEpoch}.m4a');
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: filePath);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      print("Recording failed: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      
      if (path != null) {
        final file = File(path);
        final filename = p.basename(file.path);
        final senderName = ref.read(usernameProvider);

        setState(() {
          _messages.add(ChatMessage(sender: senderName, text: "🎤 Sent Voice Memo:\n$filename", isMe: true));
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
    } catch (e) {
      print("Stop recording failed: $e");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final filename = result.files.single.name;
      final senderName = ref.read(usernameProvider);

      setState(() {
        _messages.add(ChatMessage(sender: senderName, text: "📤 Sending file: $filename...", isMe: true));
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

  void _sendTypingStatus() {
    final name = ref.read(usernameProvider);
    final payload = jsonEncode({'type': 'typing', 'sender': name});
    
    if (widget.isHost) {
      ref.read(webSocketServerProvider).broadcastMessage(payload);
    } else {
      ref.read(webSocketClientProvider).sendMessage(payload);
    }
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
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Room name
              Text(widget.room.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),

              // Connection info
              _infoTile(Icons.wifi, 'Connection',
                  widget.isHost
                      ? 'Host • ${_localIp ?? "Loading..."} : 55556'
                      : 'Client • Connected'),

              // E2EE status
              _infoTile(
                widget.room.e2eeEnabled ? Icons.lock : Icons.lock_open,
                'Encryption',
                widget.room.e2eeEnabled ? 'End-to-End Encrypted (AES-256)' : 'No encryption',
                iconColor: widget.room.e2eeEnabled ? Colors.greenAccent : Colors.grey,
              ),

              // Your display name
              _infoTile(Icons.person, 'Display Name', ref.read(usernameProvider)),

              // QR Code for host
              if (widget.isHost && _localIp != null) ...[
                const SizedBox(height: 20),
                const Text('Share this room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                const Text('Others can scan this QR code to join:',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: jsonEncode({
                        'ip': _localIp,
                        'e2ee': widget.room.e2eeEnabled,
                        'room': widget.room.name,
                      }),
                      version: QrVersions.auto,
                      size: 180.0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text('IP: $_localIp',
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ),
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
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
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
                    widget.isHost ? 'Hosting' : 'Connected',
                    style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
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
    if (msg.text.contains('.m4a') && msg.text.contains('Saved to: ')) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 36),
          onPressed: () {
            final pathMatch = msg.text.split('Saved to: ');
            if (pathMatch.length == 2) _audioPlayer.play(DeviceFileSource(pathMatch[1].trim()));
          }
        ),
        const Expanded(child: Text("🎵 Voice Memo Received", style: TextStyle(color: Colors.white, fontSize: 14))),
      ]);
    } else if (msg.text.contains('.m4a') && msg.text.startsWith('🎤 Sent Voi')) {
      return const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.audiotrack, color: Colors.white, size: 30),
        SizedBox(width: 8),
        Text("🎵 Audio message sent", style: TextStyle(color: Colors.white)),
      ]);
    } else {
      return Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15));
    }
  }

  Widget _buildMessageInput() {
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
              icon: const Icon(Icons.attach_file, color: Colors.blueAccent),
              onPressed: _pickAndSendFile,
            ),
            IconButton(
              icon: const Icon(Icons.content_paste, color: Colors.greenAccent),
              tooltip: "Sync Clipboard",
              onPressed: _syncClipboard,
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hold down the mic continuously to record!')));
              },
              onLongPress: _startRecording,
              onLongPressUp: _stopRecording,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.mic, color: _isRecording ? Colors.redAccent : Colors.orangeAccent),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => _sendTypingStatus(),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
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
              backgroundColor: Colors.blueAccent,
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            )
          ],
        ),
      ),
    );
  }
}
