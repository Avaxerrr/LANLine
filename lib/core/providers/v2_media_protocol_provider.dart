import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../db/app_database.dart';
import '../identity/identity_service.dart';
import '../network/file_transfer_manager.dart';
import '../network/v2_request_signaling_service.dart';
import '../network/webrtc_call_service.dart';
import '../repositories/attachments_repository.dart';
import '../repositories/conversations_repository.dart';
import '../repositories/messages_repository.dart';
import '../repositories/peers_repository.dart';
import 'v2_identity_provider.dart';
import 'v2_navigation_state_provider.dart';
import 'v2_repository_providers.dart';

const _noChange = Object();

class V2IncomingCall {
  final String peerId;
  final String displayName;
  final String conversationId;
  final String callId;
  final String callType;

  const V2IncomingCall({
    required this.peerId,
    required this.displayName,
    required this.conversationId,
    required this.callId,
    required this.callType,
  });
}

class V2MediaProtocolState {
  final Map<String, List<int>> downloadProgress;
  final V2IncomingCall? incomingCall;
  final String? noticeMessage;
  final String? noticeId;

  const V2MediaProtocolState({
    this.downloadProgress = const {},
    this.incomingCall,
    this.noticeMessage,
    this.noticeId,
  });

  V2MediaProtocolState copyWith({
    Map<String, List<int>>? downloadProgress,
    Object? incomingCall = _noChange,
    Object? noticeMessage = _noChange,
    Object? noticeId = _noChange,
  }) {
    return V2MediaProtocolState(
      downloadProgress: downloadProgress ?? this.downloadProgress,
      incomingCall: identical(incomingCall, _noChange)
          ? this.incomingCall
          : incomingCall as V2IncomingCall?,
      noticeMessage: identical(noticeMessage, _noChange)
          ? this.noticeMessage
          : noticeMessage as String?,
      noticeId: identical(noticeId, _noChange)
          ? this.noticeId
          : noticeId as String?,
    );
  }
}

class V2MediaProtocolNotifier extends Notifier<V2MediaProtocolState> {
  StreamSubscription<String>? _messageSubscription;
  Future<void>? _startFuture;
  LocalIdentityRow? _localIdentity;

  @override
  V2MediaProtocolState build() {
    ref.onDispose(() {
      unawaited(_messageSubscription?.cancel());
    });
    unawaited(start());
    return const V2MediaProtocolState();
  }

  IdentityService get _identityService => ref.read(identityServiceProvider);
  PeersRepository get _peersRepository => ref.read(peersRepositoryProvider);
  ConversationsRepository get _conversationsRepository =>
      ref.read(conversationsRepositoryProvider);
  MessagesRepository get _messagesRepository =>
      ref.read(messagesRepositoryProvider);
  AttachmentsRepository get _attachmentsRepository =>
      ref.read(attachmentsRepositoryProvider);
  FileTransferManager get _fileTransferManager => ref.read(fileTransferProvider);
  V2RequestSignalingService get _signalingService =>
      ref.read(v2RequestSignalingServiceProvider);

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
    await _requireReachablePresence(peerId);
    await _ensureConversation(
      peerId: peerId,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
    );
  }

  Future<void> sendFile({
    required String peerId,
    required String conversationId,
    required String conversationTitle,
    required String filePath,
  }) async {
    await start();
    final peer = await _requirePeer(peerId);
    final presence = await _requireReachablePresence(peerId);
    final conversation = await _ensureConversation(
      peerId: peerId,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
    );

    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('The selected file no longer exists.');
    }

    final size = await file.length();
    final name = p.basename(file.path);
    final mimeType = _guessMimeType(name);
    final kind = _guessAttachmentKind(name, mimeType);
    final now = DateTime.now().millisecondsSinceEpoch;

    final message = await _messagesRepository.insertMessage(
      conversationId: conversation.id,
      senderPeerId: _localIdentity!.peerId,
      type: 'file',
      textBody: name,
      status: 'pending',
      sentAt: now,
    );

    final attachment = await _attachmentsRepository.insertAttachment(
      messageId: message.id,
      kind: kind,
      fileName: name,
      fileSize: size,
      mimeType: mimeType,
      localPath: file.path,
      transferState: 'awaiting_accept',
    );

    final payload = jsonEncode({
      'protocol': 'lanline_v2_media',
      'action': 'file_offer',
      'senderPeerId': _localIdentity!.peerId,
      'senderDisplayName': _localIdentity!.displayName,
      'senderDeviceLabel': _localIdentity!.deviceLabel,
      'senderFingerprint': _localIdentity!.fingerprint,
      'conversationId': conversation.id,
      'conversationTitle': conversationTitle.isNotEmpty
          ? conversationTitle
          : peer.displayName,
      'messageId': message.id,
      'clientGeneratedId': message.clientGeneratedId,
      'attachmentId': attachment.id,
      'fileName': name,
      'fileSize': size,
      'mimeType': mimeType,
      'kind': kind,
      'sentAt': message.sentAt ?? now,
    });

    try {
      await _signalingService.sendMessage(
        host: presence.host!,
        port: presence.port ?? V2RequestSignalingService.defaultPort,
        payload: payload,
      );
      await _messagesRepository.updateMessageStatus(message.id, 'sent');
    } catch (error) {
      await _attachmentsRepository.updateAttachmentTransferMetadata(
        attachmentId: attachment.id,
        transferState: 'failed',
      );
      await _messagesRepository.updateMessageStatus(message.id, 'failed');
      throw StateError('Failed to send file offer: $error');
    }
  }

  Future<void> acceptFile({
    required String peerId,
    required String attachmentId,
  }) async {
    await start();
    final presence = await _requireReachablePresence(peerId);
    await _attachmentsRepository.updateAttachmentTransferMetadata(
      attachmentId: attachmentId,
      transferState: 'downloading',
    );

    final payload = jsonEncode({
      'protocol': 'lanline_v2_media',
      'action': 'file_accept',
      'senderPeerId': _localIdentity!.peerId,
      'senderDisplayName': _localIdentity!.displayName,
      'attachmentId': attachmentId,
    });

    await _signalingService.sendMessage(
      host: presence.host!,
      port: presence.port ?? V2RequestSignalingService.defaultPort,
      payload: payload,
    );
  }

  Future<void> cancelFileTransfer({
    required String peerId,
    required String attachmentId,
  }) async {
    await start();
    final presence = await _requireReachablePresence(peerId);

    await _attachmentsRepository.updateAttachmentTransferMetadata(
      attachmentId: attachmentId,
      transferState: 'cancelled',
    );
    _fileTransferManager.cancelFile(attachmentId);

    final updatedProgress = Map<String, List<int>>.from(state.downloadProgress)
      ..remove(attachmentId);
    state = state.copyWith(downloadProgress: updatedProgress);

    final payload = jsonEncode({
      'protocol': 'lanline_v2_media',
      'action': 'file_cancel',
      'senderPeerId': _localIdentity!.peerId,
      'senderDisplayName': _localIdentity!.displayName,
      'attachmentId': attachmentId,
    });

    await _signalingService.sendMessage(
      host: presence.host!,
      port: presence.port ?? V2RequestSignalingService.defaultPort,
      payload: payload,
    );
  }

  Future<void> sendCallSignal({
    required String peerId,
    String? conversationId,
    String? conversationTitle,
    required String payload,
  }) async {
    await start();
    final presence = await _requireReachablePresence(peerId);
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
      host: presence.host!,
      port: presence.port ?? V2RequestSignalingService.defaultPort,
      payload: jsonEncode(decoded),
    );
  }

  Future<void> declineIncomingCall(V2IncomingCall call) async {
    await sendCallSignal(
      peerId: call.peerId,
      conversationId: call.conversationId,
      payload: jsonEncode({
        'type': 'call_decline',
        'callId': call.callId,
      }),
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
  }) async {
    await start();
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    final label = callType == 'video' ? 'Video call' : 'Voice call';
    final icon = callType == 'video' ? 'Video' : 'Voice';

    await _messagesRepository.insertMessage(
      conversationId: conversationId,
      senderPeerId: _localIdentity!.peerId,
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

      final action =
          data['action']?.toString() ?? data['type']?.toString();
      if (action == null) return;

      switch (action) {
        case 'file_offer':
          await _handleIncomingFileOffer(data);
          break;
        case 'file_accept':
          await _handleIncomingFileAccept(data);
          break;
        case 'file_chunk':
          await _handleIncomingFileChunk(data);
          break;
        case 'file_downloaded':
          await _handleIncomingFileDownloaded(data);
          break;
        case 'file_cancel':
          await _handleIncomingFileCancel(data);
          break;
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
      }
    } catch (error) {
      debugPrint('[V2MediaProtocolNotifier] Failed to handle media event: $error');
    }
  }

  Future<void> _handleIncomingFileOffer(Map<String, dynamic> data) async {
    final senderPeerId = data['senderPeerId']?.toString();
    final messageId = data['messageId']?.toString();
    final attachmentId = data['attachmentId']?.toString();
    final clientGeneratedId = data['clientGeneratedId']?.toString();
    if (senderPeerId == null ||
        messageId == null ||
        attachmentId == null ||
        clientGeneratedId == null) {
      return;
    }

    final displayName = data['senderDisplayName']?.toString() ?? senderPeerId;
    final conversation = await _ensureIncomingConversation(
      peerId: senderPeerId,
      displayName: displayName,
      deviceLabel: data['senderDeviceLabel']?.toString(),
      fingerprint: data['senderFingerprint']?.toString(),
      conversationId: data['conversationId']?.toString(),
      conversationTitle: data['conversationTitle']?.toString(),
    );

    final activeConversationId = ref.read(activeConversationIdProvider);
    final existingMessage = await _messagesRepository.getMessageByClientGeneratedId(
      clientGeneratedId,
    );

    if (existingMessage == null) {
      await _messagesRepository.insertMessage(
        id: messageId,
        clientGeneratedId: clientGeneratedId,
        conversationId: conversation.id,
        senderPeerId: senderPeerId,
        type: 'file',
        textBody: data['fileName']?.toString(),
        status: activeConversationId == conversation.id ? 'read' : 'delivered',
        sentAt: data['sentAt'] as int?,
        receivedAt: DateTime.now().millisecondsSinceEpoch,
        readAt: activeConversationId == conversation.id
            ? DateTime.now().millisecondsSinceEpoch
            : null,
      );

      if (activeConversationId != conversation.id) {
        await _conversationsRepository.incrementUnreadCount(conversation.id);
      }
    }

    final existingAttachment = await _attachmentsRepository.getAttachmentById(
      attachmentId,
    );
    if (existingAttachment == null) {
      await _attachmentsRepository.insertAttachment(
        id: attachmentId,
        messageId: messageId,
        kind: data['kind']?.toString() ?? 'file',
        fileName: data['fileName']?.toString() ?? 'File',
        fileSize: data['fileSize'] as int? ?? 0,
        mimeType: data['mimeType']?.toString(),
        transferState: 'offered',
      );
    }
  }

  Future<void> _handleIncomingFileAccept(Map<String, dynamic> data) async {
    final attachmentId = data['attachmentId']?.toString();
    if (attachmentId == null) return;

    final attachment = await _attachmentsRepository.getAttachmentById(
      attachmentId,
    );
    if (attachment == null || attachment.localPath == null) return;

    final message = await _messagesRepository.getMessageById(attachment.messageId);
    if (message == null) return;

    final file = File(attachment.localPath!);
    if (!await file.exists()) {
      await _attachmentsRepository.updateAttachmentTransferMetadata(
        attachmentId: attachmentId,
        transferState: 'failed',
      );
      return;
    }

    await _attachmentsRepository.updateAttachmentTransferMetadata(
      attachmentId: attachmentId,
      transferState: 'transferring',
    );

    final payloads = await _fileTransferManager.splitFileIntoChunks(
      file,
      _localIdentity!.displayName,
      attachmentId: attachment.id,
      messageId: message.id,
      clientGeneratedId: message.clientGeneratedId,
      senderPeerId: _localIdentity!.peerId,
      senderDisplayName: _localIdentity!.displayName,
      mimeType: attachment.mimeType,
      kind: attachment.kind,
      sentAt: message.sentAt,
    );

    final senderPeerId = data['senderPeerId']?.toString();
    if (senderPeerId == null) return;
    final presence = await _requireReachablePresence(senderPeerId);

    for (final payload in payloads) {
      final chunk = jsonDecode(payload) as Map<String, dynamic>;
      chunk['protocol'] = 'lanline_v2_media';
      chunk['action'] = 'file_chunk';

      await _signalingService.sendMessage(
        host: presence.host!,
        port: presence.port ?? V2RequestSignalingService.defaultPort,
        payload: jsonEncode(chunk),
      );
    }
  }

  Future<void> _handleIncomingFileChunk(Map<String, dynamic> data) async {
    final senderPeerId = data['senderPeerId']?.toString();
    final attachmentId = data['attachmentId']?.toString();
    final messageId = data['messageId']?.toString();
    final clientGeneratedId = data['clientGeneratedId']?.toString();
    if (senderPeerId == null ||
        attachmentId == null ||
        messageId == null ||
        clientGeneratedId == null) {
      return;
    }

    final conversation = await _ensureIncomingConversation(
      peerId: senderPeerId,
      displayName: data['senderDisplayName']?.toString() ?? senderPeerId,
      deviceLabel: data['senderDeviceLabel']?.toString(),
      fingerprint: data['senderFingerprint']?.toString(),
      conversationId: data['conversationId']?.toString(),
      conversationTitle: data['conversationTitle']?.toString(),
    );

    final existingMessage = await _messagesRepository.getMessageByClientGeneratedId(
      clientGeneratedId,
    );
    if (existingMessage == null) {
      await _messagesRepository.insertMessage(
        id: messageId,
        clientGeneratedId: clientGeneratedId,
        conversationId: conversation.id,
        senderPeerId: senderPeerId,
        type: 'file',
        textBody: data['filename']?.toString(),
        status: 'delivered',
        sentAt: data['sentAt'] as int?,
        receivedAt: DateTime.now().millisecondsSinceEpoch,
      );
    }

    final attachment = await _attachmentsRepository.getAttachmentById(attachmentId);
    if (attachment == null) {
      await _attachmentsRepository.insertAttachment(
        id: attachmentId,
        messageId: messageId,
        kind: data['kind']?.toString() ?? 'file',
        fileName: data['filename']?.toString() ?? 'File',
        fileSize: data['fileSize'] as int? ?? 0,
        mimeType: data['mimeType']?.toString(),
        transferState: 'downloading',
      );
    } else if (attachment.transferState != 'downloading') {
      await _attachmentsRepository.updateAttachmentTransferMetadata(
        attachmentId: attachmentId,
        transferState: 'downloading',
      );
    }

    final total = data['total_chunks'] as int? ?? 1;
    final chunkIndex = data['chunk_index'] as int? ?? 0;
    final updatedProgress = Map<String, List<int>>.from(state.downloadProgress)
      ..[attachmentId] = [chunkIndex + 1, total];
    state = state.copyWith(downloadProgress: updatedProgress);

    final file = await _fileTransferManager.handleChunk(data);
    if (file == null) return;

    updatedProgress.remove(attachmentId);
    state = state.copyWith(downloadProgress: updatedProgress);

    await _attachmentsRepository.updateAttachmentTransferMetadata(
      attachmentId: attachmentId,
      transferState: 'completed',
      localPath: file.path,
    );

    final presence = await _requireReachablePresence(senderPeerId);
    await _signalingService.sendMessage(
      host: presence.host!,
      port: presence.port ?? V2RequestSignalingService.defaultPort,
      payload: jsonEncode({
        'protocol': 'lanline_v2_media',
        'action': 'file_downloaded',
        'senderPeerId': _localIdentity!.peerId,
        'senderDisplayName': _localIdentity!.displayName,
        'attachmentId': attachmentId,
      }),
    );
  }

  Future<void> _handleIncomingFileDownloaded(Map<String, dynamic> data) async {
    final attachmentId = data['attachmentId']?.toString();
    if (attachmentId == null) return;

    await _attachmentsRepository.updateAttachmentTransferMetadata(
      attachmentId: attachmentId,
      transferState: 'completed',
    );
  }

  Future<void> _handleIncomingFileCancel(Map<String, dynamic> data) async {
    final attachmentId = data['attachmentId']?.toString();
    if (attachmentId == null) return;

    _fileTransferManager.cancelFile(attachmentId);
    await _attachmentsRepository.updateAttachmentTransferMetadata(
      attachmentId: attachmentId,
      transferState: 'cancelled',
    );

    final updatedProgress = Map<String, List<int>>.from(state.downloadProgress)
      ..remove(attachmentId);
    state = state.copyWith(downloadProgress: updatedProgress);
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
        payload: jsonEncode({
          'type': 'call_busy',
          'callId': callId,
        }),
      );
      return;
    }

    state = state.copyWith(
      incomingCall: V2IncomingCall(
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

  Future<void> _emitNotice(String message) async {
    state = state.copyWith(
      noticeMessage: message,
      noticeId: DateTime.now().microsecondsSinceEpoch.toString(),
    );
  }

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

  Future<PeerRow> _requirePeer(String peerId) async {
    final peer = await _peersRepository.getPeerByPeerId(peerId);
    if (peer == null) {
      throw StateError('Peer $peerId is unknown.');
    }
    return peer;
  }

  Future<PresenceRow> _requireReachablePresence(String peerId) async {
    final presence = await _peersRepository.getPresenceByPeerId(peerId);
    if (presence == null || !presence.isReachable || presence.host == null) {
      throw StateError('Peer is not reachable right now.');
    }
    return presence;
  }

  String _guessAttachmentKind(String fileName, String? mimeType) {
    final ext = p.extension(fileName).toLowerCase();
    if ((mimeType?.startsWith('image/') ?? false) ||
        {
          '.jpg',
          '.jpeg',
          '.png',
          '.gif',
          '.webp',
          '.bmp',
          '.svg',
        }.contains(ext)) {
      return 'image';
    }
    if ((mimeType?.startsWith('audio/') ?? false) ||
        {'.mp3', '.m4a', '.wav', '.ogg', '.aac', '.flac'}.contains(ext)) {
      return 'audio';
    }
    if ((mimeType?.startsWith('video/') ?? false) ||
        {'.mp4', '.mov', '.mkv', '.avi', '.webm'}.contains(ext)) {
      return 'video';
    }
    return 'file';
  }

  String? _guessMimeType(String fileName) {
    switch (p.extension(fileName).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      case '.svg':
        return 'image/svg+xml';
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      case '.aac':
        return 'audio/aac';
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.mkv':
        return 'video/x-matroska';
      case '.avi':
        return 'video/x-msvideo';
      case '.webm':
        return 'video/webm';
      case '.pdf':
        return 'application/pdf';
      case '.txt':
        return 'text/plain';
      case '.json':
        return 'application/json';
      case '.csv':
        return 'text/csv';
      case '.zip':
        return 'application/zip';
      default:
        return null;
    }
  }
}

final v2MediaProtocolProvider =
    NotifierProvider<V2MediaProtocolNotifier, V2MediaProtocolState>(() {
      return V2MediaProtocolNotifier();
    });
