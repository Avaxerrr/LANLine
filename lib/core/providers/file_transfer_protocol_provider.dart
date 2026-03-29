import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../db/app_database.dart';
import '../identity/identity_service.dart';
import '../network/file_transfer_manager.dart';
import '../network/mime_utils.dart';
import '../network/peer_endpoint_resolver.dart';
import '../network/protocol_validation.dart';
import '../network/request_signaling_service.dart';
import '../repositories/attachments_repository.dart';
import '../repositories/conversations_repository.dart';
import '../repositories/messages_repository.dart';
import '../repositories/peers_repository.dart';
import 'identity_provider.dart';
import 'navigation_state_provider.dart';
import 'repository_providers.dart';

const _autoAcceptFileThresholdBytes = 4 * 1024 * 1024;

class FileTransferState {
  final Map<String, List<int>> downloadProgress;

  const FileTransferState({this.downloadProgress = const {}});

  FileTransferState copyWith({Map<String, List<int>>? downloadProgress}) {
    return FileTransferState(
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

class FileTransferNotifier extends Notifier<FileTransferState> {
  StreamSubscription<String>? _messageSubscription;
  Future<void>? _startFuture;
  LocalIdentityRow? _localIdentity;
  Future<bool> Function(HttpRequest request)? _httpRequestHandler;

  @override
  FileTransferState build() {
    final signalingService = _signalingService;
    ref.onDispose(() {
      unawaited(_messageSubscription?.cancel());
      final httpRequestHandler = _httpRequestHandler;
      if (httpRequestHandler != null) {
        signalingService.unregisterHttpHandler(httpRequestHandler);
      }
    });
    unawaited(start());
    return const FileTransferState();
  }

  IdentityService get _identityService => ref.read(identityServiceProvider);
  PeersRepository get _peersRepository => ref.read(peersRepositoryProvider);
  ConversationsRepository get _conversationsRepository =>
      ref.read(conversationsRepositoryProvider);
  MessagesRepository get _messagesRepository =>
      ref.read(messagesRepositoryProvider);
  AttachmentsRepository get _attachmentsRepository =>
      ref.read(attachmentsRepositoryProvider);
  FileTransferManager get _fileTransferManager =>
      ref.read(fileTransferProvider);
  RequestSignalingService get _signalingService =>
      ref.read(requestSignalingServiceProvider);
  PeerEndpointResolver get _endpointResolver =>
      PeerEndpointResolver(_peersRepository);

  Future<void> start() {
    if (_startFuture != null) return _startFuture!;
    _startFuture = _start();
    return _startFuture!;
  }

  Future<void> _start() async {
    _localIdentity ??= await _identityService.bootstrap();
    await _signalingService.startServer();
    _httpRequestHandler ??= _fileTransferManager.handleHttpRequest;
    _signalingService.registerHttpHandler(_httpRequestHandler!);
    _fileTransferManager.onOutgoingTransferServed ??=
        _onOutgoingTransferServed;
    _messageSubscription ??= _signalingService.onMessageReceived.listen(
      _handleIncomingSignal,
    );
  }

  Future<void> _onOutgoingTransferServed(String attachmentId) async {
    debugPrint(
      '[FileTransferNotifier] onOutgoingTransferServed: $attachmentId',
    );
    try {
      await _attachmentsRepository.updateAttachmentTransferMetadata(
        attachmentId: attachmentId,
        transferState: 'completed',
      );
    } catch (error) {
      debugPrint(
        '[FileTransferNotifier] onOutgoingTransferServed failed: $error',
      );
    }
  }

  Future<void> sendFile({
    required String peerId,
    required String conversationId,
    required String conversationTitle,
    required String filePath,
  }) async {
    await start();
    final peer = await _requirePeer(peerId);
    final endpoint = await _endpointResolver.resolve(peerId);
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
    final mimeType = guessMimeType(name);
    final kind = guessAttachmentKind(name, mimeType);
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
        host: endpoint.host,
        port: endpoint.port,
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
    String? fallbackHost,
  }) async {
    await start();
    ({String host, int port}) endpoint;
    try {
      endpoint = await _endpointResolver.resolve(peerId);
    } catch (_) {
      if (fallbackHost != null) {
        endpoint = (
          host: fallbackHost,
          port: RequestSignalingService.defaultPort,
        );
      } else {
        rethrow;
      }
    }
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
      host: endpoint.host,
      port: endpoint.port,
      payload: payload,
    );
  }

  Future<void> cancelFileTransfer({
    required String peerId,
    required String attachmentId,
  }) async {
    await start();
    final endpoint = await _endpointResolver.resolve(peerId);

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
      host: endpoint.host,
      port: endpoint.port,
      payload: payload,
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
        case 'file_offer':
          await _handleIncomingFileOffer(data);
          break;
        case 'file_accept':
          await _handleIncomingFileAccept(data);
          break;
        case 'file_ready':
          await _handleIncomingFileReady(data);
          break;
        case 'file_downloaded':
          await _handleIncomingFileDownloaded(data);
          break;
        case 'file_cancel':
          await _handleIncomingFileCancel(data);
          break;
      }
    } catch (error) {
      debugPrint(
        '[FileTransferNotifier] Failed to handle file event: $error',
      );
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
    if (!isValidProtocolIdentifier(senderPeerId) ||
        !isValidProtocolIdentifier(messageId) ||
        !isValidProtocolIdentifier(attachmentId) ||
        !isValidProtocolIdentifier(clientGeneratedId)) {
      return;
    }

    final displayName = data['senderDisplayName']?.toString() ?? senderPeerId;
    if (!isValidProtocolDisplayName(displayName)) return;
    final deviceLabel = data['senderDeviceLabel']?.toString();
    final fingerprint = data['senderFingerprint']?.toString();
    if (!isValidOptionalProtocolText(
          deviceLabel,
          maxLength: kMaxProtocolDeviceLabelLength,
        ) ||
        !isValidOptionalProtocolText(
          fingerprint,
          maxLength: kMaxProtocolFingerprintLength,
        )) {
      return;
    }

    final conversation = await _ensureIncomingConversation(
      peerId: senderPeerId,
      displayName: displayName,
      deviceLabel: deviceLabel,
      fingerprint: fingerprint,
      conversationId: data['conversationId']?.toString(),
      conversationTitle: data['conversationTitle']?.toString(),
    );

    final activeConversationId = ref.read(activeConversationIdProvider);
    final existingMessage = await _messagesRepository
        .getMessageByClientGeneratedId(clientGeneratedId);

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

    final fileSize = data['fileSize'] as int? ?? 0;
    if (fileSize < 0) return;

    final rawFileName = data['fileName']?.toString() ?? 'File';
    final rawKind = data['kind']?.toString() ?? 'file';
    final rawMimeType = data['mimeType']?.toString();
    if (!isValidOptionalProtocolText(rawFileName, maxLength: 255) ||
        !isValidOptionalProtocolText(
          rawKind,
          maxLength: kMaxProtocolIdentifierLength,
        ) ||
        !isValidOptionalProtocolText(
          rawMimeType,
          maxLength: kMaxProtocolIdentifierLength,
        )) {
      return;
    }

    final existingAttachment = await _attachmentsRepository.getAttachmentById(
      attachmentId,
    );
    if (existingAttachment == null) {
      await _attachmentsRepository.insertAttachment(
        id: attachmentId,
        messageId: messageId,
        kind: rawKind,
        fileName: rawFileName,
        fileSize: fileSize,
        mimeType: rawMimeType,
        transferState: 'offered',
      );
    }
    final remoteHost = data['_remoteHost']?.toString();

    if (fileSize > 0 && fileSize <= _autoAcceptFileThresholdBytes) {
      final canReach = await _canResolveEndpoint(senderPeerId);
      try {
        await acceptFile(
          peerId: senderPeerId,
          attachmentId: attachmentId,
          fallbackHost: canReach ? null : remoteHost,
        );
      } catch (error) {
        debugPrint(
          '[FileTransferNotifier] Failed to auto-accept small file: $error',
        );
      }
    }
  }

  Future<void> _handleIncomingFileAccept(Map<String, dynamic> data) async {
    final attachmentId = data['attachmentId']?.toString();
    if (attachmentId == null) return;

    final attachment = await _attachmentsRepository.getAttachmentById(
      attachmentId,
    );
    if (attachment == null || attachment.localPath == null) return;

    final message = await _messagesRepository.getMessageById(
      attachment.messageId,
    );
    if (message == null) return;

    final file = File(attachment.localPath!);
    if (!await file.exists()) {
      await _attachmentsRepository.updateAttachmentTransferMetadata(
        attachmentId: attachmentId,
        transferState: 'failed',
      );
      return;
    }

    debugPrint(
      '[FileTransferNotifier] file_accept received for $attachmentId, '
      'localPath=${attachment.localPath}',
    );

    await _attachmentsRepository.updateAttachmentTransferMetadata(
      attachmentId: attachmentId,
      transferState: 'transferring',
    );

    final preparedTransfer = await _fileTransferManager.prepareOutgoingTransfer(
      attachmentId: attachment.id,
      filePath: file.path,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
    );

    final senderPeerId = data['senderPeerId']?.toString();
    if (senderPeerId == null) return;
    ({String host, int port}) endpoint;
    try {
      endpoint = await _endpointResolver.resolve(senderPeerId);
    } catch (_) {
      final remoteHost = data['_remoteHost']?.toString();
      if (remoteHost != null) {
        endpoint = (
          host: remoteHost,
          port: RequestSignalingService.defaultPort,
        );
      } else {
        rethrow;
      }
    }
    debugPrint(
      '[FileTransferNotifier] Sending file_ready to ${endpoint.host}:${endpoint.port} '
      'token=${preparedTransfer.token}',
    );
    await _signalingService.sendMessage(
      host: endpoint.host,
      port: endpoint.port,
      payload: jsonEncode({
        'protocol': 'lanline_v2_media',
        'action': 'file_ready',
        'senderPeerId': _localIdentity!.peerId,
        'senderDisplayName': _localIdentity!.displayName,
        'attachmentId': attachmentId,
        'messageId': message.id,
        'clientGeneratedId': message.clientGeneratedId,
        'fileName': attachment.fileName,
        'fileSize': attachment.fileSize,
        'mimeType': attachment.mimeType,
        'kind': attachment.kind,
        'transferToken': preparedTransfer.token,
        'transferPath': preparedTransfer.path,
      }),
    );
  }

  Future<void> _handleIncomingFileReady(Map<String, dynamic> data) async {
    final senderPeerId = data['senderPeerId']?.toString();
    final attachmentId = data['attachmentId']?.toString();
    final transferToken = data['transferToken']?.toString();
    final transferPath = data['transferPath']?.toString();
    if (senderPeerId == null ||
        attachmentId == null ||
        transferToken == null ||
        transferPath == null) {
      return;
    }
    if (!isValidProtocolIdentifier(senderPeerId) ||
        !isValidProtocolIdentifier(attachmentId) ||
        !isValidProtocolIdentifier(transferToken) ||
        !isValidOptionalProtocolText(
          transferPath,
          maxLength: kMaxProtocolTextLength,
        )) {
      return;
    }

    final attachment = await _attachmentsRepository.getAttachmentById(
      attachmentId,
    );
    if (attachment == null || attachment.transferState == 'cancelled') {
      debugPrint(
        '[FileTransferNotifier] file_ready: attachment missing or cancelled '
        'for $attachmentId',
      );
      return;
    }

    ({String host, int port}) endpoint;
    try {
      endpoint = await _endpointResolver.resolve(senderPeerId);
    } catch (_) {
      final remoteHost = data['_remoteHost']?.toString();
      if (remoteHost != null) {
        endpoint = (
          host: remoteHost,
          port: RequestSignalingService.defaultPort,
        );
      } else {
        rethrow;
      }
    }
    debugPrint(
      '[FileTransferNotifier] file_ready: downloading $attachmentId from '
      '${endpoint.host}:${endpoint.port}$transferPath',
    );
    await _attachmentsRepository.updateAttachmentTransferMetadata(
      attachmentId: attachmentId,
      transferState: 'downloading',
    );

    final updatedProgress = Map<String, List<int>>.from(state.downloadProgress)
      ..[attachmentId] = [0, attachment.fileSize > 0 ? attachment.fileSize : 1];
    state = state.copyWith(downloadProgress: updatedProgress);

    try {
      final file = await _fileTransferManager.downloadFile(
        host: endpoint.host,
        port: endpoint.port,
        transferPath: transferPath,
        attachmentId: attachmentId,
        fileName: attachment.fileName,
        onProgress: (bytesReceived, totalBytes) {
          final latestProgress = Map<String, List<int>>.from(
            state.downloadProgress,
          )..[attachmentId] = [bytesReceived, totalBytes];
          state = state.copyWith(downloadProgress: latestProgress);
        },
      );

      final completedProgress = Map<String, List<int>>.from(
        state.downloadProgress,
      )..remove(attachmentId);
      state = state.copyWith(downloadProgress: completedProgress);

      await _attachmentsRepository.updateAttachmentTransferMetadata(
        attachmentId: attachmentId,
        transferState: 'completed',
        localPath: file.path,
      );

      await _signalingService.sendMessage(
        host: endpoint.host,
        port: endpoint.port,
        payload: jsonEncode({
          'protocol': 'lanline_v2_media',
          'action': 'file_downloaded',
          'senderPeerId': _localIdentity!.peerId,
          'senderDisplayName': _localIdentity!.displayName,
          'attachmentId': attachmentId,
        }),
      );
    } catch (error) {
      final failedProgress = Map<String, List<int>>.from(state.downloadProgress)
        ..remove(attachmentId);
      state = state.copyWith(downloadProgress: failedProgress);

      final refreshedAttachment = await _attachmentsRepository
          .getAttachmentById(attachmentId);
      if (refreshedAttachment?.transferState != 'cancelled') {
        await _attachmentsRepository.updateAttachmentTransferMetadata(
          attachmentId: attachmentId,
          transferState: 'failed',
        );
      }
      debugPrint('[FileTransferNotifier] HTTP file download failed: $error');
    }
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

  Future<PeerRow> _requirePeer(String peerId) async {
    final peer = await _peersRepository.getPeerByPeerId(peerId);
    if (peer == null) {
      throw StateError('Peer $peerId is unknown.');
    }
    return peer;
  }

  Future<bool> _canResolveEndpoint(String peerId) async {
    try {
      await _endpointResolver.resolve(peerId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final fileTransferProtocolProvider =
    NotifierProvider<FileTransferNotifier, FileTransferState>(() {
      return FileTransferNotifier();
    });
