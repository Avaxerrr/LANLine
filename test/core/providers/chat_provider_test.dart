import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lanline/core/models/chat_message.dart';
import 'package:lanline/core/providers/chat_provider.dart';
import '../../helpers/test_helpers.dart';

void main() {
  late ProviderContainer container;
  late MockWebSocketServer server;
  late MockWebSocketClient client;

  setUp(() async {
    final t = await createTestContainer(username: 'TestUser');
    container = t.container;
    server = t.server;
    client = t.client;
  });

  tearDown(() {
    container.dispose();
  });

  ChatNotifier notifier() => container.read(chatProvider.notifier);
  ChatState state() => container.read(chatProvider);

  group('ChatNotifier - init', () {
    test('starts with empty state', () {
      expect(state().messages, isEmpty);
      expect(state().typingUsers, isEmpty);
      expect(state().participantCount, 0);
      expect(state().hasParticipants, false);
      expect(state().roomClosed, false);
    });

    test('host starts with 0 participants', () {
      notifier().init(const ChatConfig(isHost: true, roomName: 'Test'));
      expect(state().participantCount, 0);
      expect(state().hasParticipants, false);
    });

    test('client starts with 1 participant (the host)', () {
      notifier().init(const ChatConfig(isHost: false, roomName: 'Test'));
      expect(state().participantCount, 1);
      expect(state().hasParticipants, true);
    });
  });

  group('ChatNotifier - sendMessage', () {
    setUp(() {
      notifier().init(const ChatConfig(isHost: true, roomName: 'Test'));
      // Give the host a participant so messages can be sent
      notifier().updateParticipants(count: 1, names: ['Bob']);
    });

    test('sends message and adds to state', () {
      final result = notifier().sendMessage('hello');

      expect(result, true);
      expect(state().messages.length, 1);
      expect(state().messages[0].text, 'hello');
      expect(state().messages[0].sender, 'TestUser');
      expect(state().messages[0].isMe, true);
      expect(state().messages[0].id, isNotNull);
    });

    test('broadcasts message via server when host', () {
      notifier().sendMessage('hello');

      final captured = verify(() => server.broadcastMessage(captureAny())).captured;
      expect(captured.length, 1);
      final data = jsonDecode(captured[0] as String);
      expect(data['type'], 'message');
      expect(data['text'], 'hello');
      expect(data['sender'], 'TestUser');
    });

    test('sends message via client when not host', () {
      // Re-init as client
      notifier().init(const ChatConfig(isHost: false, roomName: 'Test'));

      notifier().sendMessage('hello');

      final captured = verify(() => client.sendMessage(captureAny())).captured;
      expect(captured.length, 1);
      final data = jsonDecode(captured[0] as String);
      expect(data['type'], 'message');
      expect(data['text'], 'hello');
    });

    test('returns false and does not send when text is empty', () {
      final result = notifier().sendMessage('');

      expect(result, false);
      expect(state().messages, isEmpty);
      verifyNever(() => server.broadcastMessage(any()));
    });

    test('returns false when no participants', () {
      notifier().updateParticipants(count: 0, names: []);
      final result = notifier().sendMessage('hello');

      expect(result, false);
      expect(state().messages, isEmpty);
      verifyNever(() => server.broadcastMessage(any()));
    });
  });

  group('ChatNotifier - sendClipboard', () {
    setUp(() {
      notifier().init(const ChatConfig(isHost: true, roomName: 'Test'));
      notifier().updateParticipants(count: 1, names: ['Bob']);
    });

    test('sends clipboard and adds message to state', () {
      final result = notifier().sendClipboard('copied text');

      expect(result, 'copied text');
      expect(state().messages.length, 1);
      expect(state().messages[0].text, contains('copied text'));
      expect(state().messages[0].isMe, true);
    });

    test('broadcasts clipboard payload', () {
      notifier().sendClipboard('copied text');

      final captured = verify(() => server.broadcastMessage(captureAny())).captured;
      final data = jsonDecode(captured[0] as String);
      expect(data['type'], 'clipboard');
      expect(data['text'], 'copied text');
    });

    test('returns null when no participants', () {
      notifier().updateParticipants(count: 0, names: []);
      final result = notifier().sendClipboard('text');

      expect(result, isNull);
      expect(state().messages, isEmpty);
    });

    test('returns null when clipboard text is empty', () {
      final result = notifier().sendClipboard('');

      expect(result, isNull);
      expect(state().messages, isEmpty);
    });
  });

  group('ChatNotifier - sendTypingStatus', () {
    test('broadcasts typing indicator as host', () {
      notifier().init(const ChatConfig(isHost: true, roomName: 'Test'));
      notifier().sendTypingStatus();

      final captured = verify(() => server.broadcastMessage(captureAny())).captured;
      final data = jsonDecode(captured[0] as String);
      expect(data['type'], 'typing');
      expect(data['sender'], 'TestUser');
    });
  });

  group('ChatNotifier - message manipulation', () {
    test('addMessage appends to list', () {
      notifier().addMessage(ChatMessage(sender: 'Bob', text: 'hi', isMe: false));
      notifier().addMessage(ChatMessage(sender: 'Bob', text: 'there', isMe: false));

      expect(state().messages.length, 2);
      expect(state().messages[0].text, 'hi');
      expect(state().messages[1].text, 'there');
    });

    test('ackMessage marks correct message', () {
      notifier().addMessage(ChatMessage(id: 'msg1', sender: 'TestUser', text: 'hi', isMe: true));
      notifier().addMessage(ChatMessage(id: 'msg2', sender: 'TestUser', text: 'there', isMe: true));

      notifier().ackMessage('msg1');

      expect(state().messages[0].isAcked, true);
      expect(state().messages[1].isAcked, false);
    });

    test('ackMessage ignores non-own messages', () {
      notifier().addMessage(ChatMessage(id: 'msg1', sender: 'Bob', text: 'hi', isMe: false));
      notifier().ackMessage('msg1');

      expect(state().messages[0].isAcked, false);
    });

    test('updateMessageAt replaces message', () {
      notifier().addMessage(ChatMessage(sender: 'Bob', text: 'old', isMe: false));
      notifier().updateMessageAt(0, ChatMessage(sender: 'Bob', text: 'new', isMe: false));

      expect(state().messages[0].text, 'new');
    });

    test('updateMessageAt ignores out of bounds', () {
      notifier().addMessage(ChatMessage(sender: 'Bob', text: 'hi', isMe: false));
      notifier().updateMessageAt(5, ChatMessage(sender: 'Bob', text: 'new', isMe: false));

      expect(state().messages.length, 1);
      expect(state().messages[0].text, 'hi');
    });

    test('findMessageIndex finds by offerId and isMe', () {
      notifier().addMessage(ChatMessage(sender: 'Bob', text: '', isMe: false, offerId: 'o1'));
      notifier().addMessage(ChatMessage(sender: 'Me', text: '', isMe: true, offerId: 'o2'));

      expect(notifier().findMessageIndex('o1', isMe: false), 0);
      expect(notifier().findMessageIndex('o2', isMe: true), 1);
      expect(notifier().findMessageIndex('o1', isMe: true), -1);
      expect(notifier().findMessageIndex('nope', isMe: false), -1);
    });
  });

  group('ChatNotifier - participants', () {
    test('updateParticipants sets count and names', () {
      notifier().updateParticipants(count: 3, names: ['A', 'B', 'C']);

      expect(state().participantCount, 3);
      expect(state().participantNames, ['A', 'B', 'C']);
      expect(state().hasParticipants, true);
    });
  });

  group('ChatNotifier - typing', () {
    test('addTypingUser adds to set', () {
      notifier().addTypingUser('Alice');
      expect(state().typingUsers, {'Alice'});
    });

    test('addTypingUser is idempotent', () {
      notifier().addTypingUser('Alice');
      notifier().addTypingUser('Alice');
      expect(state().typingUsers.length, 1);
    });

    test('removeTypingUser removes from set', () {
      notifier().addTypingUser('Alice');
      notifier().addTypingUser('Bob');
      notifier().removeTypingUser('Alice');

      expect(state().typingUsers, {'Bob'});
    });

    test('removeTypingUser is safe for absent users', () {
      notifier().removeTypingUser('Nobody');
      expect(state().typingUsers, isEmpty);
    });
  });

  group('ChatNotifier - room lifecycle', () {
    test('markRoomClosed sets flag', () {
      expect(state().roomClosed, false);
      notifier().markRoomClosed();
      expect(state().roomClosed, true);
    });
  });
}
