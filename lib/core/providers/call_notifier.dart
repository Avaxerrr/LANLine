import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/webrtc_call_service.dart';
import '../models/chat_message.dart';
import 'chat_provider.dart';
import 'username_provider.dart';

/// Incoming call info passed to the widget via [onIncomingCall].
class IncomingCallInfo {
  final String sender;
  final String callId;
  final String callType;
  final String myName;

  const IncomingCallInfo({
    required this.sender,
    required this.callId,
    required this.callType,
    required this.myName,
  });
}

/// Manages call signaling: routes incoming WebRTC messages to the
/// appropriate call service methods and broadcasts outgoing signals.
///
/// UI concerns (ringtone, incoming call dialog, navigation to call screen)
/// remain in the widget via the [onIncomingCall] callback.
class CallNotifier extends Notifier<void> {
  /// Called when an incoming call arrives and the user is not busy.
  /// Widget registers this to show the incoming call dialog with ringtone.
  void Function(IncomingCallInfo info)? onIncomingCall;

  @override
  void build() {}

  void dispose() {
    onIncomingCall = null;
  }

  /// Broadcast a call signal to all participants.
  void sendCallSignal(String message) {
    ref.read(chatProvider.notifier).broadcast(message);
  }

  /// Add a call summary message to chat and broadcast it.
  void addCallSummary({
    required String myName,
    required String callType,
    required int durationSeconds,
  }) {
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    final icon = callType == 'video' ? '📹' : '📞';
    final label = callType == 'video' ? 'Video call' : 'Voice call';
    final summaryText = '$icon $label • $m:$s';

    ref.read(chatProvider.notifier).addMessage(ChatMessage(
      sender: myName,
      text: summaryText,
      isMe: true,
    ));

    sendCallSignal(jsonEncode({
      'type': 'call_summary',
      'sender': myName,
      'text': summaryText,
    }));
  }

  // ── Incoming message routing ─────────────────────────────────

  /// Handle an incoming call-related message. Returns:
  /// - `'call_start'` — incoming call (widget should show dialog via callback)
  /// - `'call_decline'` / `'call_busy'` — show snackbar with sender name
  /// - `'call_join'` / `'call_offer'` / `'call_answer'` / `'ice_candidate'` /
  ///   `'call_leave'` / `'call_end'` — signaling handled, no UI needed
  /// - `null` if not a call type
  String? handleCallMessage(String rawMessage) {
    try {
      final data = jsonDecode(rawMessage);
      final type = data['type'] as String?;

      switch (type) {
        case 'call_start':
          _handleCallStart(data);
          return type;
        case 'call_join':
          _handleCallJoin(data);
          return type;
        case 'call_offer':
          _handleCallOffer(data);
          return type;
        case 'call_answer':
          _handleCallAnswer(data);
          return type;
        case 'ice_candidate':
          _handleIceCandidate(data);
          return type;
        case 'call_leave':
        case 'call_end':
          _handleCallEnd(data);
          return type;
        case 'call_decline':
          _handleCallDecline(data);
          return type;
        case 'call_busy':
          _handleCallBusy(data);
          return type;
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  void _handleCallStart(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final callId = data['callId'] as String;
    final callType = (data['callType'] as String?) ?? 'audio';
    final myName = ref.read(usernameProvider);

    if (sender == myName) return;

    // Busy — auto-decline
    final callService = ref.read(webRtcCallServiceProvider);
    if (callService.state == CallState.inCall) {
      sendCallSignal(jsonEncode({
        'type': 'call_busy',
        'callId': callId,
        'sender': myName,
      }));
      return;
    }

    // Notify widget to show incoming call dialog
    onIncomingCall?.call(IncomingCallInfo(
      sender: sender,
      callId: callId,
      callType: callType,
      myName: myName,
    ));
  }

  void _handleCallJoin(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final myName = ref.read(usernameProvider);
    if (sender == myName) return;

    final callService = ref.read(webRtcCallServiceProvider);
    if (callService.state == CallState.inCall) {
      callService.callParticipants.add(sender);
      callService.onParticipantChanged?.call(sender, true);
      callService.setupPeerConnection(sender, myName, makeOffer: true);
    }
  }

  void _handleCallOffer(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final target = data['target'] as String;
    final myName = ref.read(usernameProvider);
    if (target != myName) return;

    ref.read(webRtcCallServiceProvider)
        .handleOffer(sender, myName, data['sdp'] as Map<String, dynamic>);
  }

  void _handleCallAnswer(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final target = data['target'] as String;
    final myName = ref.read(usernameProvider);
    if (target != myName) return;

    ref.read(webRtcCallServiceProvider)
        .handleAnswer(sender, data['sdp'] as Map<String, dynamic>);
  }

  void _handleIceCandidate(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    final target = data['target'] as String;
    final myName = ref.read(usernameProvider);
    if (target != myName) return;

    ref.read(webRtcCallServiceProvider)
        .handleIceCandidate(sender, data['candidate'] as Map<String, dynamic>);
  }

  void _handleCallEnd(Map<String, dynamic> data) {
    final sender = data['sender'] as String;
    ref.read(webRtcCallServiceProvider).handleParticipantLeft(sender);
  }

  void _handleCallDecline(Map<String, dynamic> data) {
    // Signaling only — widget checks sender for snackbar
  }

  void _handleCallBusy(Map<String, dynamic> data) {
    // Signaling only — widget checks sender for snackbar
  }
}

final callNotifierProvider = NotifierProvider<CallNotifier, void>(() {
  return CallNotifier();
});
