import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../identity/identity_service.dart';
import '../network/v2_request_signaling_service.dart';
import '../repositories/conversations_repository.dart';
import '../repositories/messages_repository.dart';
import '../repositories/peers_repository.dart';
import 'v2_identity_provider.dart';
import 'v2_repository_providers.dart';

class V2DirectMessageProtocolController {
  final V2RequestSignalingService _signalingService;
  final IdentityService _identityService;
  final PeersRepository _peersRepository;
  final ConversationsRepository _conversationsRepository;
  final MessagesRepository _messagesRepository;

  StreamSubscription<String>? _messageSubscription;
  Future<void>? _startFuture;
  LocalIdentityRow? _localIdentity;
  String? _activeConversationId;

  V2DirectMessageProtocolController({
    required V2RequestSignalingService signalingService,
    required IdentityService identityService,
    required PeersRepository peersRepository,
    required ConversationsRepository conversationsRepository,
    required MessagesRepository messagesRepository,
  }) : _signalingService = signalingService,
       _identityService = identityService,
       _peersRepository = peersRepository,
       _conversationsRepository = conversationsRepository,
       _messagesRepository = messagesRepository;

  Future<void> start() {
    if (_startFuture != null) return _startFuture!;
    _startFuture = _start();
    return _startFuture!;
  }

  Future<void> _start() async {
    _localIdentity ??= await _identityService.bootstrap();
    await _signalingService.startServer();
    _messageSubscription ??= _signalingService.onMessageReceived.listen(
      _handleIncomingMessage,
    );
  }

  Future<ConversationRow> openDirectConversation({
    required String peerId,
    String? title,
  }) async {
    await start();
    return _conversationsRepository.findOrCreateDirectConversation(
      localPeerId: _localIdentity!.peerId,
      peerId: peerId,
      title: title,
    );
  }

  Future<MessageRow> sendTextMessage({
    required String peerId,
    required String text,
    String? conversationId,
    String? conversationTitle,
    String? replyToMessageId,
  }) async {
    await start();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw StateError('Cannot send an empty message.');
    }

    final peer = await _requirePeer(peerId);
    final presence = await _requireReachablePresence(peerId);
    final conversation = conversationId != null
        ? (await _conversationsRepository.getConversationById(
                conversationId,
              )) ??
              await _conversationsRepository.findOrCreateDirectConversation(
                localPeerId: _localIdentity!.peerId,
                peerId: peerId,
                title: conversationTitle ?? peer.displayName,
              )
        : await _conversationsRepository.findOrCreateDirectConversation(
            localPeerId: _localIdentity!.peerId,
            peerId: peerId,
            title: conversationTitle ?? peer.displayName,
          );

    final message = await _messagesRepository.insertMessage(
      conversationId: conversation.id,
      senderPeerId: _localIdentity!.peerId,
      type: 'text',
      textBody: trimmed,
      status: 'pending',
      replyToMessageId: replyToMessageId,
      sentAt: DateTime.now().millisecondsSinceEpoch,
    );

    final payload = jsonEncode({
      'protocol': 'lanline_v2_message',
      'action': 'message',
      'senderPeerId': _localIdentity!.peerId,
      'senderDisplayName': _localIdentity!.displayName,
      'senderDeviceLabel': _localIdentity!.deviceLabel,
      'senderFingerprint': _localIdentity!.fingerprint,
      'clientGeneratedId': message.clientGeneratedId,
      'type': 'text',
      'text': trimmed,
      'replyToMessageId': replyToMessageId,
      'sentAt': message.sentAt,
    });

    try {
      await _signalingService.sendMessage(
        host: presence.host!,
        port: presence.port ?? V2RequestSignalingService.defaultPort,
        payload: payload,
      );
      await _messagesRepository.updateMessageStatus(message.id, 'sent');
      return (await _messagesRepository.getMessageByClientGeneratedId(
        message.clientGeneratedId,
      ))!;
    } catch (error) {
      await _messagesRepository.updateMessageStatus(message.id, 'failed');
      throw StateError('Failed to send message: $error');
    }
  }

  Future<void> setActiveConversation(String? conversationId) async {
    _activeConversationId = conversationId;
    if (conversationId != null) {
      await _conversationsRepository.markConversationRead(conversationId);
    }
  }

  Future<void> _handleIncomingMessage(String rawMessage) async {
    try {
      final data = jsonDecode(rawMessage);
      if (data is! Map<String, dynamic> ||
          data['protocol'] != 'lanline_v2_message') {
        return;
      }

      final action = data['action']?.toString();
      if (action == null) return;

      switch (action) {
        case 'message':
          await _handleIncomingTextMessage(data);
          break;
        case 'delivered':
          final clientGeneratedId = data['clientGeneratedId']?.toString();
          if (clientGeneratedId == null) return;
          await _messagesRepository.updateMessageStatusByClientGeneratedId(
            clientGeneratedId,
            'delivered',
          );
          break;
      }
    } catch (error) {
      debugPrint(
        '[V2DirectMessageProtocolController] Failed to handle message: '
        '$error',
      );
    }
  }

  Future<void> _handleIncomingTextMessage(Map<String, dynamic> data) async {
    final senderPeerId = data['senderPeerId']?.toString();
    final clientGeneratedId = data['clientGeneratedId']?.toString();
    if (senderPeerId == null || clientGeneratedId == null) return;
    if (_localIdentity != null && senderPeerId == _localIdentity!.peerId) {
      return;
    }

    final displayName = data['senderDisplayName']?.toString() ?? senderPeerId;
    final deviceLabel = data['senderDeviceLabel']?.toString();
    final fingerprint = data['senderFingerprint']?.toString();
    final existingPeer = await _peersRepository.getPeerByPeerId(senderPeerId);

    await _peersRepository.upsertPeer(
      peerId: senderPeerId,
      displayName: displayName,
      deviceLabel: deviceLabel,
      fingerprint: fingerprint,
      relationshipState: existingPeer?.relationshipState ?? 'accepted',
      isBlocked: existingPeer?.isBlocked ?? false,
    );

    final conversation = await _conversationsRepository
        .findOrCreateDirectConversation(
          localPeerId: _localIdentity!.peerId,
          peerId: senderPeerId,
          title: displayName,
        );

    final existingMessage = await _messagesRepository
        .getMessageByClientGeneratedId(clientGeneratedId);

    if (existingMessage == null) {
      await _messagesRepository.insertMessage(
        conversationId: conversation.id,
        senderPeerId: senderPeerId,
        clientGeneratedId: clientGeneratedId,
        type: data['type']?.toString() ?? 'text',
        textBody: data['text']?.toString(),
        status: _activeConversationId == conversation.id ? 'read' : 'delivered',
        replyToMessageId: data['replyToMessageId']?.toString(),
        sentAt: data['sentAt'] as int?,
        receivedAt: DateTime.now().millisecondsSinceEpoch,
        readAt: _activeConversationId == conversation.id
            ? DateTime.now().millisecondsSinceEpoch
            : null,
      );
      if (_activeConversationId != conversation.id) {
        await _conversationsRepository.incrementUnreadCount(conversation.id);
      }
    } else if (_activeConversationId == conversation.id) {
      await _conversationsRepository.markConversationRead(conversation.id);
    }

    await _sendDeliveredAck(
      peerId: senderPeerId,
      clientGeneratedId: clientGeneratedId,
    );
  }

  Future<void> _sendDeliveredAck({
    required String peerId,
    required String clientGeneratedId,
  }) async {
    final presence = await _requireReachablePresence(peerId);
    final payload = jsonEncode({
      'protocol': 'lanline_v2_message',
      'action': 'delivered',
      'senderPeerId': _localIdentity!.peerId,
      'clientGeneratedId': clientGeneratedId,
    });

    try {
      await _signalingService.sendMessage(
        host: presence.host!,
        port: presence.port ?? V2RequestSignalingService.defaultPort,
        payload: payload,
      );
    } catch (error) {
      debugPrint(
        '[V2DirectMessageProtocolController] Failed to send delivery ack: '
        '$error',
      );
    }
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

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _startFuture = null;
  }
}

final v2DirectMessageProtocolControllerProvider =
    Provider<V2DirectMessageProtocolController>((ref) {
      final controller = V2DirectMessageProtocolController(
        signalingService: ref.read(v2RequestSignalingServiceProvider),
        identityService: ref.read(identityServiceProvider),
        peersRepository: ref.read(peersRepositoryProvider),
        conversationsRepository: ref.read(conversationsRepositoryProvider),
        messagesRepository: ref.read(messagesRepositoryProvider),
      );

      unawaited(controller.start());
      ref.onDispose(controller.dispose);
      return controller;
    });
