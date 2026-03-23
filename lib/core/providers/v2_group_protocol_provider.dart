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
import 'v2_navigation_state_provider.dart';
import 'v2_repository_providers.dart';

class V2GroupProtocolController {
  final V2RequestSignalingService _signalingService;
  final IdentityService _identityService;
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
    required PeersRepository peersRepository,
    required ConversationsRepository conversationsRepository,
    required MessagesRepository messagesRepository,
    required String? Function() readActiveConversationId,
  }) : _signalingService = signalingService,
       _identityService = identityService,
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
    if (invitedPeerIds.isEmpty) {
      throw StateError('Select at least one contact to create a group.');
    }

    final peers = await _peersRepository.getPeersByPeerIds(invitedPeerIds);
    if (peers.length != invitedPeerIds.length) {
      throw StateError('One or more selected contacts are unavailable.');
    }

    final presenceByPeerId = <String, PresenceRow>{};
    for (final peer in peers) {
      if (peer.relationshipState != 'accepted') {
        throw StateError('${peer.displayName} is not an accepted contact.');
      }
      final presence = await _peersRepository.getPresenceByPeerId(peer.peerId);
      if (presence == null || !presence.isReachable || presence.host == null) {
        throw StateError('${peer.displayName} is not reachable right now.');
      }
      presenceByPeerId[peer.peerId] = presence;
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

    final payload = jsonEncode({
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
      final presence = presenceByPeerId[peer.peerId]!;
      await _signalingService.sendMessage(
        host: presence.host!,
        port: presence.port ?? V2RequestSignalingService.defaultPort,
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

    final conversation =
        await _conversationsRepository.getConversationById(conversationId);
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

    final adminPresence = await _requireReachablePresence(adminPeerId);
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
      host: adminPresence.host!,
      port: adminPresence.port ?? V2RequestSignalingService.defaultPort,
      payload: jsonEncode({
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

    final conversation =
        await _conversationsRepository.getConversationById(conversationId);
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

    final adminPresence = await _requireReachablePresence(adminPeerId);
    await _signalingService.sendMessage(
      host: adminPresence.host!,
      port: adminPresence.port ?? V2RequestSignalingService.defaultPort,
      payload: jsonEncode({
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
  }) async {
    await start();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw StateError('Cannot send an empty message.');
    }

    final conversation =
        await _conversationsRepository.getConversationById(conversationId);
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
      sentAt: DateTime.now().millisecondsSinceEpoch,
    );

    final payload = jsonEncode({
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
      final data = jsonDecode(rawMessage);
      if (data is! Map<String, dynamic> ||
          data['protocol'] != 'lanline_v2_group') {
        return;
      }

      final senderPeerId = data['senderPeerId']?.toString();
      if (senderPeerId == null ||
          (_localIdentity != null && senderPeerId == _localIdentity!.peerId)) {
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
    final conversationId = data['conversationId']?.toString();
    final title = data['title']?.toString();
    final members = data['members'];
    if (conversationId == null || title == null || members is! List) return;

    final seeds = <GroupConversationMemberSeed>[];
    for (final member in members) {
      if (member is! Map) continue;
      final peerId = member['peerId']?.toString();
      if (peerId == null) continue;
      final displayName = member['displayName']?.toString() ?? peerId;
      await _peersRepository.upsertPeer(
        peerId: peerId,
        displayName: displayName,
        deviceLabel: member['deviceLabel']?.toString(),
        fingerprint: member['fingerprint']?.toString(),
        relationshipState:
            (await _peersRepository.getPeerByPeerId(peerId))?.relationshipState ??
            (peerId == data['senderPeerId']?.toString() ? 'accepted' : 'discovered'),
        isBlocked:
            (await _peersRepository.getPeerByPeerId(peerId))?.isBlocked ?? false,
      );
      seeds.add(
        GroupConversationMemberSeed(
          peerId: peerId,
          role: member['role']?.toString() ??
              (peerId == _localIdentity!.peerId ? 'invited' : 'invited'),
        ),
      );
    }

    if (!seeds.any((seed) => seed.peerId == _localIdentity!.peerId)) {
      seeds.add(
        GroupConversationMemberSeed(peerId: _localIdentity!.peerId, role: 'invited'),
      );
    }

    await _conversationsRepository.upsertIncomingGroupConversation(
      conversationId: conversationId,
      title: title,
      members: seeds,
    );
  }

  Future<void> _handleIncomingInviteResponse(Map<String, dynamic> data) async {
    final conversationId = data['conversationId']?.toString();
    final response = data['response']?.toString();
    final senderPeerId = data['senderPeerId']?.toString();
    final senderDisplayName = data['senderDisplayName']?.toString() ?? senderPeerId;
    if (conversationId == null || response == null || senderPeerId == null) {
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
    final conversationId = data['conversationId']?.toString();
    final memberPeerId = data['memberPeerId']?.toString();
    final role = data['role']?.toString();
    final memberDisplayName =
        data['memberDisplayName']?.toString() ?? memberPeerId;
    if (conversationId == null || memberPeerId == null || role == null) return;

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
    final conversationId = data['conversationId']?.toString();
    final senderPeerId = data['senderPeerId']?.toString();
    final clientGeneratedId = data['clientGeneratedId']?.toString();
    if (conversationId == null ||
        senderPeerId == null ||
        clientGeneratedId == null) {
      return;
    }

    final membership = await _conversationsRepository.getMembership(
      conversationId: conversationId,
      peerId: _localIdentity!.peerId,
    );
    if (membership == null || membership.role == 'invited') {
      return;
    }

    final senderDisplayName = data['senderDisplayName']?.toString() ?? senderPeerId;
    final existingPeer = await _peersRepository.getPeerByPeerId(senderPeerId);
    await _peersRepository.upsertPeer(
      peerId: senderPeerId,
      displayName: senderDisplayName,
      deviceLabel: data['senderDeviceLabel']?.toString(),
      fingerprint: data['senderFingerprint']?.toString(),
      relationshipState: existingPeer?.relationshipState ?? 'accepted',
      isBlocked: existingPeer?.isBlocked ?? false,
    );

    final existingMessage = await _messagesRepository.getMessageByClientGeneratedId(
      clientGeneratedId,
    );
    if (existingMessage != null) return;

    final activeConversationId = _readActiveConversationId();
    await _messagesRepository.insertMessage(
      conversationId: conversationId,
      senderPeerId: senderPeerId,
      clientGeneratedId: clientGeneratedId,
      type: data['type']?.toString() ?? 'text',
      textBody: data['text']?.toString(),
      status: activeConversationId == conversationId ? 'read' : 'delivered',
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

  Future<List<PresenceRow>> _resolveReachableTargets(String conversationId) async {
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
    final conversation =
        await _conversationsRepository.getConversationById(conversationId);
    if (conversation == null) return;

    final member = await _peersRepository.getPeerByPeerId(memberPeerId);
    final targets = await _resolveMemberBroadcastTargets(conversationId);
    final payload = jsonEncode({
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
      final presence = await _peersRepository.getPresenceByPeerId(member.peerId);
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

final v2GroupProtocolControllerProvider =
    Provider<V2GroupProtocolController>((ref) {
      final controller = V2GroupProtocolController(
        signalingService: ref.read(v2RequestSignalingServiceProvider),
        identityService: ref.read(identityServiceProvider),
        peersRepository: ref.read(peersRepositoryProvider),
        conversationsRepository: ref.read(conversationsRepositoryProvider),
        messagesRepository: ref.read(messagesRepositoryProvider),
        readActiveConversationId: () => ref.read(activeConversationIdProvider),
      );

      unawaited(controller.start());
      ref.onDispose(controller.dispose);
      return controller;
    });
