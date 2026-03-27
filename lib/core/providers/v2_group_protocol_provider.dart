import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../identity/identity_service.dart';
import '../network/protocol_validation.dart';
import '../network/v2_request_signaling_service.dart';
import '../repositories/conversations_repository.dart';
import '../repositories/messages_repository.dart';
import '../repositories/peers_repository.dart';
import '../security/device_signature_service.dart';
import 'security_providers.dart';
import 'v2_identity_provider.dart';
import 'v2_navigation_state_provider.dart';
import 'v2_repository_providers.dart';

class V2GroupProtocolController {
  final V2RequestSignalingService _signalingService;
  final IdentityService _identityService;
  final DeviceSignatureService _deviceSignatureService;
  final PeersRepository _peersRepository;
  final ConversationsRepository _conversationsRepository;
  final MessagesRepository _messagesRepository;
  final String? Function() _readActiveConversationId;

  StreamSubscription<String>? _messageSubscription;
  Future<void>? _startFuture;
  LocalIdentityRow? _localIdentity;

  V2GroupProtocolController({
    required V2RequestSignalingService signalingService,
    required IdentityService identityService,
    required DeviceSignatureService deviceSignatureService,
    required PeersRepository peersRepository,
    required ConversationsRepository conversationsRepository,
    required MessagesRepository messagesRepository,
    required String? Function() readActiveConversationId,
  }) : _signalingService = signalingService,
       _identityService = identityService,
       _deviceSignatureService = deviceSignatureService,
       _peersRepository = peersRepository,
       _conversationsRepository = conversationsRepository,
       _messagesRepository = messagesRepository,
       _readActiveConversationId = readActiveConversationId;

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

  Future<ConversationRow> createGroupConversation({
    required String title,
    required List<String> invitedPeerIds,
  }) async {
    await start();
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw StateError('Group name cannot be empty.');
    }
    if (!isValidOptionalProtocolText(
      trimmedTitle,
      maxLength: kMaxProtocolGroupTitleLength,
    )) {
      throw StateError('Group name is too long.');
    }
    if (invitedPeerIds.isEmpty) {
      throw StateError('Select at least one contact to create a group.');
    }

    final peers = await _peersRepository.getPeersByPeerIds(invitedPeerIds);
    if (peers.length != invitedPeerIds.length) {
      throw StateError('One or more selected contacts are unavailable.');
    }

    final endpointByPeerId = <String, ({String host, int port})>{};
    for (final peer in peers) {
      if (peer.relationshipState != 'accepted') {
        throw StateError('${peer.displayName} is not an accepted contact.');
      }
      endpointByPeerId[peer.peerId] = await _resolveEndpoint(peer.peerId);
    }

    final conversation = await _conversationsRepository.createGroupConversation(
      localPeerId: _localIdentity!.peerId,
      title: trimmedTitle,
      invitedPeerIds: invitedPeerIds,
    );

    await _addSystemMessage(
      conversationId: conversation.id,
      text: '${_localIdentity!.displayName} created the group.',
    );

    final membersPayload = [
      {
        'peerId': _localIdentity!.peerId,
        'displayName': _localIdentity!.displayName,
        'deviceLabel': _localIdentity!.deviceLabel,
        'fingerprint': _localIdentity!.fingerprint,
        'role': 'admin',
      },
      for (final peer in peers)
        {
          'peerId': peer.peerId,
          'displayName': peer.displayName,
          'deviceLabel': peer.deviceLabel,
          'fingerprint': peer.fingerprint,
          'role': 'invited',
        },
    ];

    final payload = await _buildSignedPayload({
      'protocol': 'lanline_v2_group',
      'action': 'group_invite',
      'conversationId': conversation.id,
      'title': trimmedTitle,
      'senderPeerId': _localIdentity!.peerId,
      'senderDisplayName': _localIdentity!.displayName,
      'members': membersPayload,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    for (final peer in peers) {
      final endpoint = endpointByPeerId[peer.peerId]!;
      await _signalingService.sendMessage(
        host: endpoint.host,
        port: endpoint.port,
        payload: payload,
      );
    }

    return conversation;
  }

  Future<void> acceptGroupInvite(String conversationId) async {
    await start();
    final membership = await _requireMembership(
      conversationId: conversationId,
      peerId: _localIdentity!.peerId,
    );
    if (membership.role != 'invited') return;

    final conversation = await _conversationsRepository.getConversationById(
      conversationId,
    );
    if (conversation == null) {
      throw StateError('Group invite no longer exists.');
    }

    final members = await _conversationsRepository.getConversationMembers(
      conversationId,
    );
    final adminPeerId = _findAdminPeerId(members);
    if (adminPeerId == null) {
      throw StateError('Group admin could not be determined.');
    }

    final adminEndpoint = await _resolveEndpoint(adminPeerId);
    await _conversationsRepository.updateMemberRole(
      conversationId: conversationId,
      peerId: _localIdentity!.peerId,
      role: 'member',
    );

    await _addSystemMessage(
      conversationId: conversationId,
      text: 'You joined the group.',
    );

    await _signalingService.sendMessage(
      host: adminEndpoint.host,
      port: adminEndpoint.port,
      payload: await _buildSignedPayload({
        'protocol': 'lanline_v2_group',
        'action': 'group_invite_response',
        'response': 'accepted',
        'conversationId': conversationId,
        'title': conversation.title,
        'senderPeerId': _localIdentity!.peerId,
        'senderDisplayName': _localIdentity!.displayName,
      }),
    );
  }

  Future<void> declineGroupInvite(String conversationId) async {
    await start();
    final membership = await _requireMembership(
      conversationId: conversationId,
      peerId: _localIdentity!.peerId,
    );
    if (membership.role != 'invited') return;

    final conversation = await _conversationsRepository.getConversationById(
      conversationId,
    );
    if (conversation == null) {
      throw StateError('Group invite no longer exists.');
    }

    final members = await _conversationsRepository.getConversationMembers(
      conversationId,
    );
    final adminPeerId = _findAdminPeerId(members);
    if (adminPeerId == null) {
      await _conversationsRepository.deleteConversation(conversationId);
      return;
    }

    final adminEndpoint = await _resolveEndpoint(adminPeerId);
    await _signalingService.sendMessage(
      host: adminEndpoint.host,
      port: adminEndpoint.port,
      payload: await _buildSignedPayload({
        'protocol': 'lanline_v2_group',
        'action': 'group_invite_response',
        'response': 'declined',
        'conversationId': conversationId,
        'title': conversation.title,
        'senderPeerId': _localIdentity!.peerId,
        'senderDisplayName': _localIdentity!.displayName,
      }),
    );

    await _conversationsRepository.deleteConversation(conversationId);
  }

  Future<MessageRow> sendGroupTextMessage({
    required String conversationId,
    required String text,
    String? replyToMessageId,
  }) async {
    await start();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw StateError('Cannot send an empty message.');
    }
    if (!isValidOptionalProtocolText(
      trimmed,
      maxLength: kMaxProtocolTextLength,
    )) {
      throw StateError('Message is too long.');
    }

    final conversation = await _conversationsRepository.getConversationById(
      conversationId,
    );
    if (conversation == null || conversation.type != 'group') {
      throw StateError('Conversation is not a group chat.');
    }

    final targets = await _resolveReachableTargets(conversationId);
    if (targets.isEmpty) {
      throw StateError('No joined group members are reachable right now.');
    }

    final message = await _messagesRepository.insertMessage(
      conversationId: conversationId,
      senderPeerId: _localIdentity!.peerId,
      type: 'text',
      textBody: trimmed,
      status: 'pending',
      replyToMessageId: replyToMessageId,
      sentAt: DateTime.now().millisecondsSinceEpoch,
    );

    final payload = await _buildSignedPayload({
      'protocol': 'lanline_v2_group',
      'action': 'group_message',
      'conversationId': conversationId,
      'title': conversation.title,
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
      for (final target in targets) {
        await _signalingService.sendMessage(
          host: target.host!,
          port: target.port ?? V2RequestSignalingService.defaultPort,
          payload: payload,
        );
      }
      await _messagesRepository.updateMessageStatus(message.id, 'sent');
      return (await _messagesRepository.getMessageByClientGeneratedId(
        message.clientGeneratedId,
      ))!;
    } catch (error) {
      await _messagesRepository.updateMessageStatus(message.id, 'failed');
      throw StateError('Failed to send group message: $error');
    }
  }

  Future<void> _handleIncomingMessage(String rawMessage) async {
    try {
      _localIdentity ??= await _identityService.bootstrap();
      final data = jsonDecode(rawMessage);
      if (data is! Map<String, dynamic> ||
          data['protocol'] != 'lanline_v2_group') {
        return;
      }

      final rawSenderPeerId = data['senderPeerId']?.toString();
      if (!isValidProtocolIdentifier(rawSenderPeerId) ||
          (_localIdentity != null &&
              rawSenderPeerId == _localIdentity!.peerId)) {
        return;
      }
      if (!isValidOptionalProtocolText(
            data['senderSigningPublicKey']?.toString(),
            maxLength: kMaxProtocolSigningPublicKeyLength,
          ) ||
          !isValidOptionalProtocolText(
            data['signature']?.toString(),
            maxLength: kMaxProtocolSignatureLength,
          )) {
        return;
      }
      switch (data['action']) {
        case 'group_invite':
          await _handleIncomingInvite(data);
          break;
        case 'group_invite_response':
          await _handleIncomingInviteResponse(data);
          break;
        case 'group_member_update':
          await _handleIncomingMemberUpdate(data);
          break;
        case 'group_message':
          await _handleIncomingGroupMessage(data);
          break;
      }
    } catch (error) {
      debugPrint(
        '[V2GroupProtocolController] Failed to handle group message: $error',
      );
    }
  }

  Future<void> _handleIncomingInvite(Map<String, dynamic> data) async {
    final rawConversationId = data['conversationId']?.toString();
    final title = data['title']?.toString();
    final members = data['members'];
    final rawSenderPeerId = data['senderPeerId']?.toString();
    if (!isValidProtocolIdentifier(rawConversationId) ||
        !isValidOptionalProtocolText(
          title,
          maxLength: kMaxProtocolGroupTitleLength,
        ) ||
        !isValidProtocolIdentifier(rawSenderPeerId) ||
        members is! List) {
      return;
    }
    final conversationId = rawConversationId!.trim();
    final senderPeerId = rawSenderPeerId!.trim();
    final normalizedTitle = title!.trim();

    final senderPeer = await _peersRepository.getPeerByPeerId(senderPeerId);
    final verified = await _verifySignedPayload(
      data,
      fallbackPublicKey:
          senderPeer?.signingPublicKey ??
          data['senderSigningPublicKey']?.toString(),
    );
    if (!verified) {
      return;
    }
    final isTrustedSender =
        senderPeer != null &&
        !senderPeer.isBlocked &&
        (senderPeer.relationshipState == 'accepted' ||
            senderPeer.relationshipState == 'pending_outgoing');
    if (!isTrustedSender) return;

    final seeds = <GroupConversationMemberSeed>[];
    for (final member in members) {
      if (member is! Map) continue;
      final rawPeerId = member['peerId']?.toString();
      if (!isValidProtocolIdentifier(rawPeerId)) continue;
      final peerId = rawPeerId!.trim();
      final displayName =
          isValidProtocolDisplayName(member['displayName']?.toString())
          ? member['displayName']!.toString().trim()
          : peerId;
      final existingPeer = await _peersRepository.getPeerByPeerId(peerId);
      await _peersRepository.upsertPeer(
        peerId: peerId,
        displayName: displayName,
        deviceLabel:
            isValidOptionalProtocolText(
              member['deviceLabel']?.toString(),
              maxLength: kMaxProtocolDeviceLabelLength,
            )
            ? member['deviceLabel']?.toString().trim()
            : existingPeer?.deviceLabel,
        fingerprint:
            isValidOptionalProtocolText(
              member['fingerprint']?.toString(),
              maxLength: kMaxProtocolFingerprintLength,
            )
            ? member['fingerprint']?.toString().trim()
            : existingPeer?.fingerprint,
        signingPublicKey: peerId == senderPeerId
            ? data['senderSigningPublicKey']?.toString().trim()
            : existingPeer?.signingPublicKey,
        relationshipState:
            existingPeer?.relationshipState ??
            (peerId == senderPeerId ? 'accepted' : 'discovered'),
        isBlocked: existingPeer?.isBlocked ?? false,
      );
      seeds.add(
        GroupConversationMemberSeed(
          peerId: peerId,
          role:
              member['role']?.toString() ??
              (peerId == _localIdentity!.peerId ? 'invited' : 'invited'),
        ),
      );
    }

    if (!seeds.any((seed) => seed.peerId == _localIdentity!.peerId)) {
      seeds.add(
        GroupConversationMemberSeed(
          peerId: _localIdentity!.peerId,
          role: 'invited',
        ),
      );
    }

    await _conversationsRepository.upsertIncomingGroupConversation(
      conversationId: conversationId,
      title: normalizedTitle,
      members: seeds,
    );
  }

  Future<void> _handleIncomingInviteResponse(Map<String, dynamic> data) async {
    final rawConversationId = data['conversationId']?.toString();
    final response = data['response']?.toString();
    final rawSenderPeerId = data['senderPeerId']?.toString();
    final senderDisplayName =
        data['senderDisplayName']?.toString() ?? rawSenderPeerId;
    if (!isValidProtocolIdentifier(rawConversationId) ||
        response == null ||
        !isValidProtocolIdentifier(rawSenderPeerId)) {
      return;
    }
    final conversationId = rawConversationId!.trim();
    final senderPeerId = rawSenderPeerId!.trim();
    final existingPeer = await _peersRepository.getPeerByPeerId(senderPeerId);
    final verified = await _verifySignedPayload(
      data,
      fallbackPublicKey:
          existingPeer?.signingPublicKey ??
          data['senderSigningPublicKey']?.toString(),
    );
    if (!verified) {
      return;
    }

    final senderMembership = await _conversationsRepository.getMembership(
      conversationId: conversationId,
      peerId: senderPeerId,
    );
    if (senderMembership == null || senderMembership.role != 'invited') {
      return;
    }

    if (response == 'accepted') {
      await _conversationsRepository.updateMemberRole(
        conversationId: conversationId,
        peerId: senderPeerId,
        role: 'member',
      );
      await _addSystemMessage(
        conversationId: conversationId,
        text: '$senderDisplayName joined the group.',
      );
      await _broadcastMemberUpdate(
        conversationId: conversationId,
        memberPeerId: senderPeerId,
        role: 'member',
      );
      return;
    }

    if (response == 'declined') {
      await _conversationsRepository.removeMember(
        conversationId: conversationId,
        peerId: senderPeerId,
      );
      await _addSystemMessage(
        conversationId: conversationId,
        text: '$senderDisplayName declined the invite.',
      );
      await _broadcastMemberUpdate(
        conversationId: conversationId,
        memberPeerId: senderPeerId,
        role: 'removed',
      );
    }
  }

  Future<void> _handleIncomingMemberUpdate(Map<String, dynamic> data) async {
    final rawConversationId = data['conversationId']?.toString();
    final rawSenderPeerId = data['senderPeerId']?.toString();
    final rawMemberPeerId = data['memberPeerId']?.toString();
    final role = data['role']?.toString();
    final memberDisplayName =
        data['memberDisplayName']?.toString() ?? rawMemberPeerId;
    if (!isValidProtocolIdentifier(rawConversationId) ||
        !isValidProtocolIdentifier(rawSenderPeerId) ||
        !isValidProtocolIdentifier(rawMemberPeerId) ||
        role == null) {
      return;
    }
    final conversationId = rawConversationId!.trim();
    final senderPeerId = rawSenderPeerId!.trim();
    final memberPeerId = rawMemberPeerId!.trim();
    final existingPeer = await _peersRepository.getPeerByPeerId(senderPeerId);
    final verified = await _verifySignedPayload(
      data,
      fallbackPublicKey:
          existingPeer?.signingPublicKey ??
          data['senderSigningPublicKey']?.toString(),
    );
    if (!verified) {
      return;
    }

    final senderMembership = await _conversationsRepository.getMembership(
      conversationId: conversationId,
      peerId: senderPeerId,
    );
    if (senderMembership?.role != 'admin') {
      return;
    }

    if (role == 'removed') {
      if (memberPeerId == _localIdentity!.peerId) {
        await _conversationsRepository.deleteConversation(conversationId);
        return;
      }
      await _conversationsRepository.removeMember(
        conversationId: conversationId,
        peerId: memberPeerId,
      );
      await _addSystemMessage(
        conversationId: conversationId,
        text: '$memberDisplayName left the group.',
      );
      return;
    }

    await _conversationsRepository.updateMemberRole(
      conversationId: conversationId,
      peerId: memberPeerId,
      role: role,
    );

    if (role == 'member' && memberPeerId != _localIdentity!.peerId) {
      await _addSystemMessage(
        conversationId: conversationId,
        text: '$memberDisplayName joined the group.',
      );
    }
  }

  Future<void> _handleIncomingGroupMessage(Map<String, dynamic> data) async {
    final rawConversationId = data['conversationId']?.toString();
    final rawSenderPeerId = data['senderPeerId']?.toString();
    final rawClientGeneratedId = data['clientGeneratedId']?.toString();
    final text = data['text']?.toString();
    if (!isValidProtocolIdentifier(rawConversationId) ||
        !isValidProtocolIdentifier(rawSenderPeerId) ||
        !isValidProtocolIdentifier(rawClientGeneratedId) ||
        !isValidOptionalProtocolText(text, maxLength: kMaxProtocolTextLength)) {
      return;
    }
    final conversationId = rawConversationId!.trim();
    final senderPeerId = rawSenderPeerId!.trim();
    final clientGeneratedId = rawClientGeneratedId!.trim();
    final senderSigningPublicKey = data['senderSigningPublicKey']?.toString();

    final membership = await _conversationsRepository.getMembership(
      conversationId: conversationId,
      peerId: _localIdentity!.peerId,
    );
    if (membership == null || membership.role == 'invited') {
      return;
    }

    final existingPeer = await _peersRepository.getPeerByPeerId(senderPeerId);
    final verified = await _verifySignedPayload(
      data,
      fallbackPublicKey:
          existingPeer?.signingPublicKey ?? senderSigningPublicKey,
    );
    if (!verified) {
      return;
    }
    final senderMembership = await _conversationsRepository.getMembership(
      conversationId: conversationId,
      peerId: senderPeerId,
    );
    final isTrustedSender =
        existingPeer != null &&
        !existingPeer.isBlocked &&
        (existingPeer.relationshipState == 'accepted' ||
            existingPeer.relationshipState == 'pending_outgoing') &&
        senderMembership != null &&
        senderMembership.role != 'invited';
    if (!isTrustedSender) {
      return;
    }

    final senderDisplayName =
        isValidProtocolDisplayName(data['senderDisplayName']?.toString())
        ? data['senderDisplayName']!.toString().trim()
        : existingPeer.displayName;
    await _peersRepository.upsertPeer(
      peerId: senderPeerId,
      displayName: senderDisplayName,
      deviceLabel:
          isValidOptionalProtocolText(
            data['senderDeviceLabel']?.toString(),
            maxLength: kMaxProtocolDeviceLabelLength,
          )
          ? data['senderDeviceLabel']?.toString().trim()
          : existingPeer.deviceLabel,
      fingerprint:
          isValidOptionalProtocolText(
            data['senderFingerprint']?.toString(),
            maxLength: kMaxProtocolFingerprintLength,
          )
          ? data['senderFingerprint']?.toString().trim()
          : existingPeer.fingerprint,
      signingPublicKey:
          senderSigningPublicKey?.trim() ?? existingPeer.signingPublicKey,
      relationshipState: existingPeer.relationshipState,
      isBlocked: existingPeer.isBlocked,
    );

    final existingMessage = await _messagesRepository
        .getMessageByClientGeneratedId(clientGeneratedId);
    if (existingMessage != null) return;

    final activeConversationId = _readActiveConversationId();
    await _messagesRepository.insertMessage(
      conversationId: conversationId,
      senderPeerId: senderPeerId,
      clientGeneratedId: clientGeneratedId,
      type: data['type']?.toString() ?? 'text',
      textBody: text,
      status: activeConversationId == conversationId ? 'read' : 'delivered',
      replyToMessageId: data['replyToMessageId']?.toString(),
      sentAt: data['sentAt'] as int?,
      receivedAt: DateTime.now().millisecondsSinceEpoch,
      readAt: activeConversationId == conversationId
          ? DateTime.now().millisecondsSinceEpoch
          : null,
    );

    if (activeConversationId != conversationId) {
      await _conversationsRepository.incrementUnreadCount(conversationId);
    }
  }

  Future<List<PresenceRow>> _resolveReachableTargets(
    String conversationId,
  ) async {
    final targetIds = await _conversationsRepository.getMessageTargetPeerIds(
      conversationId: conversationId,
      localPeerId: _localIdentity!.peerId,
    );

    final presences = <PresenceRow>[];
    for (final peerId in targetIds) {
      final presence = await _peersRepository.getPresenceByPeerId(peerId);
      if (presence != null && presence.isReachable && presence.host != null) {
        presences.add(presence);
      }
    }
    return presences;
  }

  Future<void> _broadcastMemberUpdate({
    required String conversationId,
    required String memberPeerId,
    required String role,
  }) async {
    final conversation = await _conversationsRepository.getConversationById(
      conversationId,
    );
    if (conversation == null) return;

    final member = await _peersRepository.getPeerByPeerId(memberPeerId);
    final targets = await _resolveMemberBroadcastTargets(conversationId);
    final payload = await _buildSignedPayload({
      'protocol': 'lanline_v2_group',
      'action': 'group_member_update',
      'conversationId': conversationId,
      'title': conversation.title,
      'senderPeerId': _localIdentity!.peerId,
      'senderDisplayName': _localIdentity!.displayName,
      'memberPeerId': memberPeerId,
      'memberDisplayName': member?.displayName ?? memberPeerId,
      'role': role,
    });

    for (final target in targets) {
      try {
        await _signalingService.sendMessage(
          host: target.host!,
          port: target.port ?? V2RequestSignalingService.defaultPort,
          payload: payload,
        );
      } catch (error) {
        debugPrint(
          '[V2GroupProtocolController] Failed to fan out member update: $error',
        );
      }
    }
  }

  Future<List<PresenceRow>> _resolveMemberBroadcastTargets(
    String conversationId,
  ) async {
    final members = await _conversationsRepository.getConversationMembers(
      conversationId,
    );
    final targets = <PresenceRow>[];
    for (final member in members) {
      if (member.peerId == _localIdentity!.peerId) continue;
      final presence = await _peersRepository.getPresenceByPeerId(
        member.peerId,
      );
      if (presence != null && presence.isReachable && presence.host != null) {
        targets.add(presence);
      }
    }
    return targets;
  }

  Future<void> _addSystemMessage({
    required String conversationId,
    required String text,
  }) async {
    await _messagesRepository.insertMessage(
      conversationId: conversationId,
      senderPeerId: _localIdentity!.peerId,
      type: 'system',
      textBody: text,
      status: 'read',
      sentAt: DateTime.now().millisecondsSinceEpoch,
      readAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<ConversationMemberRow> _requireMembership({
    required String conversationId,
    required String peerId,
  }) async {
    final membership = await _conversationsRepository.getMembership(
      conversationId: conversationId,
      peerId: peerId,
    );
    if (membership == null) {
      throw StateError('Conversation membership was not found.');
    }
    return membership;
  }

  String? _findAdminPeerId(List<ConversationMemberRow> members) {
    for (final member in members) {
      if (member.role == 'admin') return member.peerId;
    }
    return null;
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
      return (
        host: host,
        port: peer.tunnelPort ?? V2RequestSignalingService.defaultPort,
      );
    }

    final presence = await _peersRepository.getPresenceByPeerId(peerId);
    if (presence == null || !presence.isReachable || presence.host == null) {
      throw StateError('Peer is not reachable right now.');
    }
    return (
      host: presence.host!,
      port: presence.port ?? V2RequestSignalingService.defaultPort,
    );
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _startFuture = null;
  }

  Future<String> _buildSignedPayload(Map<String, dynamic> payload) async {
    final signingPublicKey =
        _localIdentity!.signingPublicKey ??
        (await _deviceSignatureService.ensureIdentity()).publicKey;
    final signature = await _deviceSignatureService.signPayload(payload);
    return jsonEncode({
      ...payload,
      'senderSigningPublicKey': signingPublicKey,
      'signature': signature,
    });
  }

  Future<bool> _verifySignedPayload(
    Map<String, dynamic> payload, {
    required String? fallbackPublicKey,
  }) async {
    final signature = payload['signature']?.toString();
    final publicKey =
        payload['senderSigningPublicKey']?.toString() ?? fallbackPublicKey;
    if (signature == null ||
        publicKey == null ||
        !isValidOptionalProtocolText(
          signature,
          maxLength: kMaxProtocolSignatureLength,
        ) ||
        !isValidOptionalProtocolText(
          publicKey,
          maxLength: kMaxProtocolSigningPublicKeyLength,
        )) {
      return false;
    }

    final signedPayload = Map<String, dynamic>.from(payload)
      ..remove('signature')
      ..remove('senderSigningPublicKey');
    return _deviceSignatureService.verifyPayload(
      payload: signedPayload,
      publicKeyBase64: publicKey,
      signatureBase64: signature,
    );
  }
}

final v2GroupProtocolControllerProvider = Provider<V2GroupProtocolController>((
  ref,
) {
  final controller = V2GroupProtocolController(
    signalingService: ref.read(v2RequestSignalingServiceProvider),
    identityService: ref.read(identityServiceProvider),
    deviceSignatureService: ref.read(deviceSignatureServiceProvider),
    peersRepository: ref.read(peersRepositoryProvider),
    conversationsRepository: ref.read(conversationsRepositoryProvider),
    messagesRepository: ref.read(messagesRepositoryProvider),
    readActiveConversationId: () => ref.read(activeConversationIdProvider),
  );

  unawaited(controller.start());
  ref.onDispose(controller.dispose);
  return controller;
});
