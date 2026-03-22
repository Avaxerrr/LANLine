import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../network/websocket_server.dart';
import '../network/websocket_client.dart';
import 'username_provider.dart';

/// Configuration passed when initializing the chat session.
class ChatConfig {
  final bool isHost;
  final String roomName;

  const ChatConfig({required this.isHost, required this.roomName});
}

/// Immutable state for the chat session.
class ChatState {
  final List<ChatMessage> messages;
  final Set<String> typingUsers;
  final int participantCount;
  final List<String> participantNames;
  final bool roomClosed;

  const ChatState({
    this.messages = const [],
    this.typingUsers = const {},
    this.participantCount = 0,
    this.participantNames = const [],
    this.roomClosed = false,
  });

  bool get hasParticipants => participantCount > 0;

  ChatState copyWith({
    List<ChatMessage>? messages,
    Set<String>? typingUsers,
    int? participantCount,
    List<String>? participantNames,
    bool? roomClosed,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      typingUsers: typingUsers ?? this.typingUsers,
      participantCount: participantCount ?? this.participantCount,
      participantNames: participantNames ?? this.participantNames,
      roomClosed: roomClosed ?? this.roomClosed,
    );
  }
}

/// Manages chat message state and sending logic.
///
/// Must be initialized with [init] before use. The widget calls this
/// once in initState with the appropriate [ChatConfig].
class ChatNotifier extends Notifier<ChatState> {
  ChatConfig? _config;

  @override
  ChatState build() => const ChatState();

  /// Initialize the notifier for a chat session.
  void init(ChatConfig config) {
    _config = config;
    // Client always has at least the host as a participant
    if (!config.isHost) {
      state = state.copyWith(participantCount: 1);
    }
  }

  bool get isHost => _config?.isHost ?? false;

  // ── Sending ──────────────────────────────────────────────────

  /// Sends a text message. Returns true if sent, false if blocked
  /// (empty text or no participants).
  bool sendMessage(String text) {
    if (text.isEmpty) return false;
    if (!state.hasParticipants) return false;

    final name = ref.read(usernameProvider);
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final payload = jsonEncode({
      'type': 'message',
      'id': msgId,
      'sender': name,
      'text': text,
    });

    _send(payload);

    state = state.copyWith(
      messages: [...state.messages, ChatMessage(id: msgId, sender: name, text: text, isMe: true)],
    );
    return true;
  }

  /// Sends a clipboard sync to all participants. Returns the clipboard
  /// text if sent, null if blocked.
  String? sendClipboard(String clipboardText) {
    if (clipboardText.isEmpty) return null;
    if (!state.hasParticipants) return null;

    final senderName = ref.read(usernameProvider);
    final payload = jsonEncode({
      'type': 'clipboard',
      'sender': senderName,
      'text': clipboardText,
    });
    _send(payload);

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          sender: senderName,
          text: '📋 Splashed Clipboard:\n$clipboardText',
          isMe: true,
        ),
      ],
    );
    return clipboardText;
  }

  /// Sends a typing indicator to other participants.
  void sendTypingStatus() {
    final name = ref.read(usernameProvider);
    final payload = jsonEncode({'type': 'typing', 'sender': name});
    _send(payload);
  }

  // ── Adding messages from external sources ────────────────────

  /// Add a message directly to the list (used by file transfer,
  /// call notifiers, and incoming message handler).
  void addMessage(ChatMessage message) {
    state = state.copyWith(messages: [...state.messages, message]);
  }

  /// Replace a message at a specific index (used for updating
  /// file offer states, ack status, etc.).
  void updateMessageAt(int index, ChatMessage message) {
    final updated = [...state.messages];
    if (index >= 0 && index < updated.length) {
      updated[index] = message;
      state = state.copyWith(messages: updated);
    }
  }

  /// Update a message by matching its offerId.
  void updateMessageByOfferId(String offerId, ChatMessage Function(ChatMessage old) updater, {bool senderOnly = false}) {
    final updated = [...state.messages];
    for (int i = 0; i < updated.length; i++) {
      if (updated[i].offerId == offerId && (!senderOnly || updated[i].isMe)) {
        updated[i] = updater(updated[i]);
      }
    }
    state = state.copyWith(messages: updated);
  }

  /// Find message index by offerId and isMe flag.
  int findMessageIndex(String offerId, {required bool isMe}) {
    return state.messages.indexWhere((m) => m.offerId == offerId && m.isMe == isMe);
  }

  /// Mark a sent message as acknowledged (blue tick).
  void ackMessage(String messageId) {
    final updated = [...state.messages];
    for (var msg in updated) {
      if (msg.id == messageId && msg.isMe) {
        msg.isAcked = true;
        break;
      }
    }
    state = state.copyWith(messages: updated);
  }

  // ── Participant tracking ─────────────────────────────────────

  void updateParticipants({required int count, required List<String> names}) {
    state = state.copyWith(participantCount: count, participantNames: names);
  }

  // ── Typing indicators ────────────────────────────────────────

  void addTypingUser(String name) {
    if (!state.typingUsers.contains(name)) {
      state = state.copyWith(typingUsers: {...state.typingUsers, name});
    }
  }

  void removeTypingUser(String name) {
    if (state.typingUsers.contains(name)) {
      final updated = {...state.typingUsers}..remove(name);
      state = state.copyWith(typingUsers: updated);
    }
  }

  // ── Room lifecycle ───────────────────────────────────────────

  void markRoomClosed() {
    state = state.copyWith(roomClosed: true);
  }

  // ── Send helper ──────────────────────────────────────────────

  /// Send a raw payload through the appropriate WebSocket channel.
  void _send(String payload) {
    if (_config == null) return;
    if (_config!.isHost) {
      ref.read(webSocketServerProvider).broadcastMessage(payload);
    } else {
      ref.read(webSocketClientProvider).sendMessage(payload);
    }
  }

  /// Public send for other notifiers/widgets that need to broadcast
  /// raw payloads (e.g., file transfer, call signaling).
  void broadcast(String payload) => _send(payload);
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});
