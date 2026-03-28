import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../identity/identity_service.dart';
import '../network/request_signaling_service.dart';
import '../network/webrtc_call_service.dart';
import '../repositories/conversations_repository.dart';
import '../repositories/messages_repository.dart';
import '../repositories/peers_repository.dart';
import 'identity_provider.dart';
import 'repository_providers.dart';

const _noChange = Object();

class IncomingCall {
  final String peerId;
  final String displayName;
  final String conversationId;
  final String callId;
  final String callType;

  const IncomingCall({
    required this.peerId,
    required this.displayName,
    required this.conversationId,
    required this.callId,
    required this.callType,
  });
}

class CallSignalingState {
  final IncomingCall? incomingCall;
  final String? noticeMessage;
  final String? noticeId;

  const CallSignalingState({
    this.incomingCall,
    this.noticeMessage,
    this.noticeId,
  });

  CallSignalingState copyWith({
    Object? incomingCall = _noChange,
    Object? noticeMessage = _noChange,
    Object? noticeId = _noChange,
  }) {
    return CallSignalingState(
      incomingCall: identical(incomingCall, _noChange)
          ? this.incomingCall
          : incomingCall as IncomingCall?,
      noticeMessage: identical(noticeMessage, _noChange)
          ? this.noticeMessage
          : noticeMessage as String?,
      noticeId: identical(noticeId, _noChange)
          ? this.noticeId
          : noticeId as String?,
    );
  }
}

class CallSignalingNotifier extends Notifier<CallSignalingState> {
  StreamSubscription<String>? _messageSubscription;
  Future<void>? _startFuture;
  LocalIdentityRow? _localIdentity;

  @override
  CallSignalingState build() {
    ref.onDispose(() {
      unawaited(_messageSubscription?.cancel());
    });
    unawaited(start());
    return const CallSignalingState();
  }

  IdentityService get _identityService => ref.read(identityServiceProvider);
  PeersRepository get _peersRepository => ref.read(peersRepositoryProvider);
  ConversationsRepository get _conversationsRepository =>
      ref.read(conversationsRepositoryProvider);
  MessagesRepository get _messagesRepository =>
      ref.read(messagesRepositoryProvider);
  RequestSignalingService get _signalingService =>
      ref.read(requestSignalingServiceProvider);

  Future<void> start() {
    if (_startFuture != null) return _startFuture!;
    _startFuture = _start();
    return _startFuture!;
  }

  Future<void> _start() async {
    _localIdentity ??= await _identityService.bootstrap();
    await _signalingService.startServer();
    _messageSubscription ??= _signalingService.onMessageReceived.listen(
      _handleIncomingSignal,
    );
  }

  Future<void> prepareOutgoingCall({
    required String peerId,
    required String conversationId,
    required String conversationTitle,
    required String callType,
  }) async {
    await start();
    await _resolveEndpoint(peerId);
    await _ensureConversation(
      peerId: peerId,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
    );
  }

  Future<void> sendCallSignal({
    required String peerId,
    String? conversationId,
    String? conversationTitle,
    required String payload,
  }) async {
    await start();
    final endpoint = await _resolveEndpoint(peerId);
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Invalid call payload.');
    }

    decoded['protocol'] = 'lanline_v2_media';
    decoded['senderPeerId'] = _localIdentity!.peerId;
    decoded['senderDisplayName'] = _localIdentity!.displayName;
    decoded['senderDeviceLabel'] = _localIdentity!.deviceLabel;
    decoded['senderFingerprint'] = _localIdentity!.fingerprint;
    if (conversationId != null) {
      decoded['conversationId'] = conversationId;
    }
    if (conversationTitle != null && conversationTitle.isNotEmpty) {
      decoded['conversationTitle'] = conversationTitle;
    }
    if (decoded['targetPeerId'] == null &&
        decoded['target'] != null &&
        decoded['target'] == peerId) {
      decoded['targetPeerId'] = peerId;
    }

    await _signalingService.sendMessage(
      host: endpoint.host,
      port: endpoint.port,
      payload: jsonEncode(decoded),
    );
  }

  Future<void> declineIncomingCall(IncomingCall call) async {
    await sendCallSignal(
      peerId: call.peerId,
      conversationId: call.conversationId,
      payload: jsonEncode({'type': 'call_decline', 'callId': call.callId}),
    );
    await clearIncomingCall();
  }

  Future<void> clearIncomingCall() async {
    state = state.copyWith(incomingCall: null);
  }

  Future<void> clearNotice() async {
    state = state.copyWith(noticeMessage: null, noticeId: null);
  }

  Future<void> addLocalCallSummary({
    required String conversationId,
    required String callType,
    required int durationSeconds,
    String? senderPeerId,
  }) async {
    await start();
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    final label = callType == 'video' ? 'Video call' : 'Voice call';
    final icon = callType == 'video' ? 'Video' : 'Voice';

    await _messagesRepository.insertMessage(
      conversationId: conversationId,
      senderPeerId: senderPeerId ?? _localIdentity!.peerId,
      type: 'call_summary',
      textBody: '$icon call • $m:$s',
      status: 'read',
      sentAt: DateTime.now().millisecondsSinceEpoch,
      readAt: DateTime.now().millisecondsSinceEpoch,
      metadataJson: jsonEncode({
        'callType': callType,
        'durationSeconds': durationSeconds,
        'label': label,
      }),
    );
  }

  Future<void> _handleIncomingSignal(String rawMessage) async {
    try {
      final data = jsonDecode(rawMessage);
      if (data is! Map<String, dynamic> ||
          data['protocol'] != 'lanline_v2_media') {
        return;
      }

      final action = data['action']?.toString() ?? data['type']?.toString();
      if (action == null) return;

      switch (action) {
        case CallSignal.callStart:
          await _handleIncomingCallStart(data);
          break;
        case CallSignal.callJoin:
          await _handleIncomingCallJoin(data);
          break;
        case CallSignal.callOffer:
          await _handleIncomingCallOffer(data);
          break;
        case CallSignal.callAnswer:
          await _handleIncomingCallAnswer(data);
          break;
        case CallSignal.iceCandidate:
          await _handleIncomingIceCandidate(data);
          break;
        case CallSignal.callLeave:
        case CallSignal.callEnd:
          await _handleIncomingCallEnd(data);
          break;
        case 'call_busy':
          await _handleIncomingCallBusy(data);
          break;
        case 'call_decline':
          await _handleIncomingCallDecline(data);
          break;
        case 'call_video_toggle':
          _handleIncomingVideoToggle(data);
          break;
      }
    } catch (error) {
      debugPrint(
        '[CallSignalingNotifier] Failed to handle call event: $error',
      );
    }
  }

  Future<void> _handleIncomingCallStart(Map<String, dynamic> data) async {
    final senderPeerId = data['senderPeerId']?.toString();
    final callId = data['callId']?.toString();
    if (senderPeerId == null || callId == null) return;
    if (senderPeerId == _localIdentity?.peerId) return;

    final displayName = data['senderDisplayName']?.toString() ?? senderPeerId;
    final conversation = await _ensureIncomingConversation(
      peerId: senderPeerId,
      displayName: displayName,
      deviceLabel: data['senderDeviceLabel']?.toString(),
      fingerprint: data['senderFingerprint']?.toString(),
      conversationId: data['conversationId']?.toString(),
      conversationTitle: data['conversationTitle']?.toString(),
    );

    final callService = ref.read(webRtcCallServiceProvider);
    if (callService.state == CallState.inCall ||
        callService.state == CallState.calling) {
      await sendCallSignal(
        peerId: senderPeerId,
        conversationId: conversation.id,
        payload: jsonEncode({'type': 'call_busy', 'callId': callId}),
      );
      return;
    }

    state = state.copyWith(
      incomingCall: IncomingCall(
        peerId: senderPeerId,
        displayName: displayName,
        conversationId: conversation.id,
        callId: callId,
        callType: data['callType']?.toString() ?? 'audio',
      ),
    );
  }

  Future<void> _handleIncomingCallJoin(Map<String, dynamic> data) async {
    final senderPeerId = data['senderPeerId']?.toString();
    if (senderPeerId == null || senderPeerId == _localIdentity?.peerId) return;

    final callService = ref.read(webRtcCallServiceProvider);
    if (callService.state == CallState.inCall) {
      callService.callParticipants.add(senderPeerId);
      callService.onParticipantChanged?.call(senderPeerId, true);
      await callService.setupPeerConnection(
        senderPeerId,
        _localIdentity!.peerId,
        makeOffer: true,
      );
    }
  }

  Future<void> _handleIncomingCallOffer(Map<String, dynamic> data) async {
    final senderPeerId = data['senderPeerId']?.toString();
    final targetPeerId =
        data['targetPeerId']?.toString() ?? data['target']?.toString();
    if (senderPeerId == null || targetPeerId != _localIdentity?.peerId) return;

    await ref
        .read(webRtcCallServiceProvider)
        .handleOffer(
          senderPeerId,
          _localIdentity!.peerId,
          Map<String, dynamic>.from(data['sdp'] as Map),
        );
  }

  Future<void> _handleIncomingCallAnswer(Map<String, dynamic> data) async {
    final senderPeerId = data['senderPeerId']?.toString();
    final targetPeerId =
        data['targetPeerId']?.toString() ?? data['target']?.toString();
    if (senderPeerId == null || targetPeerId != _localIdentity?.peerId) return;

    await ref
        .read(webRtcCallServiceProvider)
        .handleAnswer(
          senderPeerId,
          Map<String, dynamic>.from(data['sdp'] as Map),
        );
  }

  Future<void> _handleIncomingIceCandidate(Map<String, dynamic> data) async {
    final senderPeerId = data['senderPeerId']?.toString();
    final targetPeerId =
        data['targetPeerId']?.toString() ?? data['target']?.toString();
    if (senderPeerId == null || targetPeerId != _localIdentity?.peerId) return;

    await ref
        .read(webRtcCallServiceProvider)
        .handleIceCandidate(
          senderPeerId,
          Map<String, dynamic>.from(data['candidate'] as Map),
        );
  }

  Future<void> _handleIncomingCallEnd(Map<String, dynamic> data) async {
    final senderPeerId = data['senderPeerId']?.toString();
    if (senderPeerId == null) return;
    ref.read(webRtcCallServiceProvider).handleParticipantLeft(senderPeerId);
  }

  Future<void> _handleIncomingCallBusy(Map<String, dynamic> data) async {
    await ref.read(webRtcCallServiceProvider).dispose();
    await _emitNotice(
      '${data['senderDisplayName']?.toString() ?? 'Contact'} is on another call.',
    );
  }

  Future<void> _handleIncomingCallDecline(Map<String, dynamic> data) async {
    await ref.read(webRtcCallServiceProvider).dispose();
    await _emitNotice(
      '${data['senderDisplayName']?.toString() ?? 'Contact'} declined the call.',
    );
  }

  void _handleIncomingVideoToggle(Map<String, dynamic> data) {
    final senderPeerId = data['senderPeerId']?.toString();
    if (senderPeerId == null) return;
    final videoEnabled = data['videoEnabled'] == true;
    ref
        .read(webRtcCallServiceProvider)
        .onRemoteVideoToggle
        ?.call(senderPeerId, videoEnabled);
  }

  Future<void> _emitNotice(String message) async {
    state = state.copyWith(
      noticeMessage: message,
      noticeId: DateTime.now().microsecondsSinceEpoch.toString(),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────

  Future<ConversationRow> _ensureIncomingConversation({
    required String peerId,
    required String displayName,
    String? deviceLabel,
    String? fingerprint,
    String? conversationId,
    String? conversationTitle,
  }) async {
    final existingPeer = await _peersRepository.getPeerByPeerId(peerId);
    await _peersRepository.upsertPeer(
      peerId: peerId,
      displayName: displayName,
      deviceLabel: deviceLabel,
      fingerprint: fingerprint,
      relationshipState: existingPeer?.relationshipState ?? 'accepted',
      isBlocked: existingPeer?.isBlocked ?? false,
    );

    if (conversationId != null) {
      final existingConversation = await _conversationsRepository
          .getConversationById(conversationId);
      if (existingConversation != null) {
        return existingConversation;
      }
    }

    return _conversationsRepository.findOrCreateDirectConversation(
      localPeerId: _localIdentity!.peerId,
      peerId: peerId,
      title: conversationTitle ?? displayName,
    );
  }

  Future<ConversationRow> _ensureConversation({
    required String peerId,
    required String conversationId,
    required String conversationTitle,
  }) async {
    final existing = await _conversationsRepository.getConversationById(
      conversationId,
    );
    if (existing != null) return existing;

    return _conversationsRepository.findOrCreateDirectConversation(
      localPeerId: _localIdentity!.peerId,
      peerId: peerId,
      title: conversationTitle,
    );
  }

  Future<({String host, int port})> _resolveEndpoint(String peerId) async {
    final peer = await _peersRepository.getPeerByPeerId(peerId);
    if (peer != null && peer.useTunnel) {
      final host = peer.tunnelHost?.trim();
      if (host == null || host.isEmpty) {
        throw StateError(
          'Tunnel is enabled but no tunnel host is configured.',
        );
      }
      final port = peer.tunnelPort ?? RequestSignalingService.defaultPort;
      return (host: host, port: port);
    }

    final presence = await _peersRepository.getPresenceByPeerId(peerId);
    if (presence == null || !presence.isReachable || presence.host == null) {
      throw StateError('Peer is not reachable right now.');
    }
    return (
      host: presence.host!,
      port: presence.port ?? RequestSignalingService.defaultPort,
    );
  }
}

final callSignalingProvider =
    NotifierProvider<CallSignalingNotifier, CallSignalingState>(() {
      return CallSignalingNotifier();
    });
