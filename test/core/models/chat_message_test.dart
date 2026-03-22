import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('creates with required fields and defaults', () {
      final msg = ChatMessage(sender: 'Alice', text: 'hello', isMe: true);

      expect(msg.sender, 'Alice');
      expect(msg.text, 'hello');
      expect(msg.isMe, true);
      expect(msg.id, isNull);
      expect(msg.filePath, isNull);
      expect(msg.fileName, isNull);
      expect(msg.offerId, isNull);
      expect(msg.fileSize, isNull);
      expect(msg.isAcked, false);
      expect(msg.isDownloading, false);
      expect(msg.isExpired, false);
      expect(msg.isCancelled, false);
    });

    test('uses provided timestamp when given', () {
      final ts = DateTime(2026, 1, 15, 10, 30);
      final msg = ChatMessage(sender: 'A', text: 'hi', isMe: false, timestamp: ts);
      expect(msg.timestamp, ts);
    });

    test('auto-generates timestamp when not given', () {
      final before = DateTime.now();
      final msg = ChatMessage(sender: 'A', text: 'hi', isMe: false);
      final after = DateTime.now();

      expect(msg.timestamp.isAfter(before) || msg.timestamp.isAtSameMomentAs(before), true);
      expect(msg.timestamp.isBefore(after) || msg.timestamp.isAtSameMomentAs(after), true);
    });

    test('creates file message with all fields', () {
      final msg = ChatMessage(
        id: 'msg_1',
        sender: 'Bob',
        text: '',
        isMe: false,
        filePath: '/downloads/photo.jpg',
        fileName: 'photo.jpg',
        offerId: 'offer_123',
        fileSize: 1024000,
      );

      expect(msg.filePath, '/downloads/photo.jpg');
      expect(msg.fileName, 'photo.jpg');
      expect(msg.offerId, 'offer_123');
      expect(msg.fileSize, 1024000);
    });

    test('mutable state fields can be updated', () {
      final msg = ChatMessage(sender: 'A', text: 'hi', isMe: true);

      msg.isAcked = true;
      msg.isDownloading = true;
      msg.isCancelled = true;

      expect(msg.isAcked, true);
      expect(msg.isDownloading, true);
      expect(msg.isCancelled, true);
    });
  });

  group('isEmojiOnly', () {
    test('returns true for single emoji', () {
      expect(isEmojiOnly('😀'), true);
      expect(isEmojiOnly('🔥'), true);
    });

    test('returns true for 2-3 emojis', () {
      expect(isEmojiOnly('😀🔥'), true);
      expect(isEmojiOnly('👍🎉🔥'), true);
    });

    test('returns false for text with emoji', () {
      expect(isEmojiOnly('hello 😀'), false);
      expect(isEmojiOnly('😀 hello'), false);
    });

    test('returns false for plain text', () {
      expect(isEmojiOnly('hello'), false);
      expect(isEmojiOnly('abc'), false);
    });

    test('returns false for empty string', () {
      expect(isEmojiOnly(''), false);
    });

    test('handles whitespace around emojis', () {
      expect(isEmojiOnly(' 😀 '), true);
    });
  });

  group('isImageFile', () {
    test('returns true for common image extensions', () {
      expect(isImageFile('/path/photo.jpg'), true);
      expect(isImageFile('/path/photo.jpeg'), true);
      expect(isImageFile('/path/photo.png'), true);
      expect(isImageFile('/path/photo.gif'), true);
      expect(isImageFile('/path/photo.webp'), true);
      expect(isImageFile('/path/photo.bmp'), true);
    });

    test('returns true regardless of case', () {
      expect(isImageFile('/path/PHOTO.JPG'), true);
      expect(isImageFile('/path/Photo.Png'), true);
    });

    test('returns false for non-image files', () {
      expect(isImageFile('/path/doc.pdf'), false);
      expect(isImageFile('/path/audio.m4a'), false);
      expect(isImageFile('/path/video.mp4'), false);
      expect(isImageFile('/path/file.txt'), false);
      expect(isImageFile('/path/app.apk'), false);
    });

    test('returns false for null', () {
      expect(isImageFile(null), false);
    });

    test('returns false for path with no extension', () {
      expect(isImageFile('/path/noext'), false);
    });
  });
}
