import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanline/core/providers/call_notifier.dart';
import 'package:lanline/core/providers/chat_provider.dart';
import 'package:lanline/core/network/webrtc_call_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  late ProviderContainer container;
  late MockWebSocketServer server;
  late MockWebRtcCallService callService;

  setUp(() async {
    final env = await createTestContainer(username: 'Alice');
    container = env.container;
    server = env.server;
    callService = env.callService;

    when(() => server.broadcastMessage(any())).thenReturn(null);
    when(() => env.client.sendMessage(any())).thenReturn(null);
  });

  tearDown(() => container.dispose());

  void initAsHost() {
    container.read(chatProvider.notifier).init(
      const ChatConfig(isHost: true, roomName: 'TestRoom'),
    );
    container.read(chatProvider.notifier).updateParticipants(
      count: 1, names: ['Bob'],
    );
  }

  group('CallNotifier -', () {
    group('sendCallSignal -', () {
      test('broadcasts message', () {
        initAsHost();
        container.read(callNotifierProvider.notifier)
            .sendCallSignal('{"type":"test"}');
        verify(() => server.broadcastMessage('{"type":"test"}')).called(1);
      });
    });

    group('addCallSummary -', () {
      test('adds message and broadcasts summary', () {
        initAsHost();
        container.read(callNotifierProvider.notifier).addCallSummary(
          myName: 'Alice',
          callType: 'audio',
          durationSeconds: 125,
        );

        final messages = container.read(chatProvider).messages;
        expect(messages.length, 1);
        expect(messages.first.text, contains('Voice call'));
        expect(messages.first.text, contains('02:05'));
        expect(messages.first.isMe, true);

        final captured = verify(() => server.broadcastMessage(captureAny())).captured;
        final summaryMsg = captured.firstWhere(
          (m) => m.toString().contains('call_summary'),
        );
        final decoded = jsonDecode(summaryMsg as String);
        expect(decoded['type'], 'call_summary');
        expect(decoded['sender'], 'Alice');
      });

      test('formats video call correctly', () {
        initAsHost();
        container.read(callNotifierProvider.notifier).addCallSummary(
          myName: 'Alice',
          callType: 'video',
          durationSeconds: 60,
        );

        final messages = container.read(chatProvider).messages;
        expect(messages.first.text, contains('Video call'));
        expect(messages.first.text, contains('📹'));
      });
    });

    group('handleCallMessage -', () {
      test('call_start invokes onIncomingCall when not busy', () {
        initAsHost();
        callService.state = CallState.idle;

        IncomingCallInfo? receivedInfo;
        container.read(callNotifierProvider.notifier).onIncomingCall = (info) {
          receivedInfo = info;
        };

        final raw = jsonEncode({
          'type': 'call_start',
          'sender': 'Bob',
          'callId': 'call_123',
          'callType': 'video',
        });

        final result = container.read(callNotifierProvider.notifier)
            .handleCallMessage(raw);

        expect(result, 'call_start');
        expect(receivedInfo, isNotNull);
        expect(receivedInfo!.sender, 'Bob');
        expect(receivedInfo!.callId, 'call_123');
        expect(receivedInfo!.callType, 'video');
        expect(receivedInfo!.myName, 'Alice');
      });

      test('call_start auto-declines when busy', () {
        initAsHost();
        callService.state = CallState.inCall;

        IncomingCallInfo? receivedInfo;
        container.read(callNotifierProvider.notifier).onIncomingCall = (info) {
          receivedInfo = info;
        };

        final raw = jsonEncode({
          'type': 'call_start',
          'sender': 'Bob',
          'callId': 'call_123',
          'callType': 'audio',
        });

        container.read(callNotifierProvider.notifier).handleCallMessage(raw);

        // Should NOT invoke callback
        expect(receivedInfo, isNull);

        // Should broadcast call_busy
        final captured = verify(() => server.broadcastMessage(captureAny())).captured;
        final busyMsg = captured.firstWhere(
          (m) => m.toString().contains('call_busy'),
        );
        final decoded = jsonDecode(busyMsg as String);
        expect(decoded['type'], 'call_busy');
        expect(decoded['sender'], 'Alice');
      });

      test('call_start ignores own messages', () {
        initAsHost();
        callService.state = CallState.idle;

        IncomingCallInfo? receivedInfo;
        container.read(callNotifierProvider.notifier).onIncomingCall = (info) {
          receivedInfo = info;
        };

        final raw = jsonEncode({
          'type': 'call_start',
          'sender': 'Alice', // same as username
          'callId': 'call_123',
        });

        container.read(callNotifierProvider.notifier).handleCallMessage(raw);
        expect(receivedInfo, isNull);
      });

      test('call_join sets up peer connection when in call', () {
        initAsHost();
        callService.state = CallState.inCall;

        when(() => callService.setupPeerConnection(any(), any(), makeOffer: true))
            .thenAnswer((_) async {});

        final raw = jsonEncode({
          'type': 'call_join',
          'sender': 'Bob',
        });

        final result = container.read(callNotifierProvider.notifier)
            .handleCallMessage(raw);

        expect(result, 'call_join');
        expect(callService.callParticipants, contains('Bob'));
        verify(() => callService.setupPeerConnection('Bob', 'Alice', makeOffer: true)).called(1);
      });

      test('call_offer delegates to call service', () {
        initAsHost();

        when(() => callService.handleOffer(any(), any(), any()))
            .thenAnswer((_) async {});

        final raw = jsonEncode({
          'type': 'call_offer',
          'sender': 'Bob',
          'target': 'Alice',
          'sdp': {'type': 'offer', 'sdp': 'v=0...'},
        });

        final result = container.read(callNotifierProvider.notifier)
            .handleCallMessage(raw);

        expect(result, 'call_offer');
        verify(() => callService.handleOffer('Bob', 'Alice', any())).called(1);
      });

      test('call_offer ignores messages not targeted at us', () {
        initAsHost();

        final raw = jsonEncode({
          'type': 'call_offer',
          'sender': 'Bob',
          'target': 'Charlie', // not us
          'sdp': {'type': 'offer', 'sdp': 'v=0...'},
        });

        container.read(callNotifierProvider.notifier).handleCallMessage(raw);
        verifyNever(() => callService.handleOffer(any(), any(), any()));
      });

      test('call_answer delegates to call service', () {
        initAsHost();

        when(() => callService.handleAnswer(any(), any()))
            .thenAnswer((_) async {});

        final raw = jsonEncode({
          'type': 'call_answer',
          'sender': 'Bob',
          'target': 'Alice',
          'sdp': {'type': 'answer', 'sdp': 'v=0...'},
        });

        final result = container.read(callNotifierProvider.notifier)
            .handleCallMessage(raw);

        expect(result, 'call_answer');
        verify(() => callService.handleAnswer('Bob', any())).called(1);
      });

      test('ice_candidate delegates to call service', () {
        initAsHost();

        when(() => callService.handleIceCandidate(any(), any()))
            .thenAnswer((_) async {});

        final raw = jsonEncode({
          'type': 'ice_candidate',
          'sender': 'Bob',
          'target': 'Alice',
          'candidate': {'candidate': 'a=...', 'sdpMid': '0'},
        });

        final result = container.read(callNotifierProvider.notifier)
            .handleCallMessage(raw);

        expect(result, 'ice_candidate');
        verify(() => callService.handleIceCandidate('Bob', any())).called(1);
      });

      test('call_end delegates to call service', () {
        initAsHost();

        when(() => callService.handleParticipantLeft(any()))
            .thenAnswer((_) async {});

        final raw = jsonEncode({
          'type': 'call_end',
          'sender': 'Bob',
        });

        final result = container.read(callNotifierProvider.notifier)
            .handleCallMessage(raw);

        expect(result, 'call_end');
        verify(() => callService.handleParticipantLeft('Bob')).called(1);
      });

      test('call_decline returns type for widget snackbar', () {
        initAsHost();

        final raw = jsonEncode({
          'type': 'call_decline',
          'sender': 'Bob',
          'callId': 'call_123',
        });

        final result = container.read(callNotifierProvider.notifier)
            .handleCallMessage(raw);
        expect(result, 'call_decline');
      });

      test('call_busy returns type for widget snackbar', () {
        initAsHost();

        final raw = jsonEncode({
          'type': 'call_busy',
          'sender': 'Bob',
          'callId': 'call_123',
        });

        final result = container.read(callNotifierProvider.notifier)
            .handleCallMessage(raw);
        expect(result, 'call_busy');
      });

      test('returns null for non-call types', () {
        initAsHost();
        final raw = jsonEncode({'type': 'message', 'sender': 'Bob', 'text': 'hi'});
        final result = container.read(callNotifierProvider.notifier)
            .handleCallMessage(raw);
        expect(result, null);
      });

      test('returns null for invalid JSON', () {
        initAsHost();
        final result = container.read(callNotifierProvider.notifier)
            .handleCallMessage('not json');
        expect(result, null);
      });
    });

    group('dispose -', () {
      test('clears onIncomingCall callback', () {
        container.read(callNotifierProvider.notifier).onIncomingCall = (_) {};
        container.read(callNotifierProvider.notifier).dispose();
        // Should not throw
      });
    });
  });
}
