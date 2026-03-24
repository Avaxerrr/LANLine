import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../repositories/messages_repository.dart';
import '../repositories/conversations_repository.dart';
import 'v2_direct_message_protocol_provider.dart';
import 'v2_group_protocol_provider.dart';
import 'v2_identity_provider.dart';
import 'v2_media_protocol_provider.dart';
import 'v2_navigation_state_provider.dart';
import 'v2_presence_discovery_provider.dart';
import 'v2_request_protocol_provider.dart';
import 'v2_repository_providers.dart';

class PreviewCrowdedUiNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool value) {
    state = value;
  }
}

final previewCrowdedUiProvider =
    NotifierProvider<PreviewCrowdedUiNotifier, bool>(
      PreviewCrowdedUiNotifier.new,
    );

final contactsProvider = StreamProvider((ref) {
  ref.watch(v2PresenceDiscoveryControllerProvider);
  return ref.read(peersRepositoryProvider).watchAcceptedContacts();
});

final previewContactsProvider = Provider<List<PeerRow>>((ref) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return [
    PeerRow(
      id: 'mock-peer-1',
      peerId: 'mock-peer-1',
      displayName: 'Ken',
      deviceLabel: 'Ken\'s Phone',
      fingerprint: 'ABE2-7C',
      relationshipState: 'accepted',
      isBlocked: false,
      lastSeenAt: now - const Duration(minutes: 3).inMilliseconds,
      createdAt: now,
      updatedAt: now,
    ),
    PeerRow(
      id: 'mock-peer-2',
      peerId: 'mock-peer-2',
      displayName: 'Aira',
      deviceLabel: 'Aira Laptop',
      fingerprint: 'H3Q1-9L',
      relationshipState: 'accepted',
      isBlocked: false,
      lastSeenAt: now - const Duration(minutes: 14).inMilliseconds,
      createdAt: now,
      updatedAt: now,
    ),
    PeerRow(
      id: 'mock-peer-3',
      peerId: 'mock-peer-3',
      displayName: 'Marco',
      deviceLabel: 'Studio PC',
      fingerprint: 'LK22-0P',
      relationshipState: 'accepted',
      isBlocked: false,
      lastSeenAt: now - const Duration(hours: 2).inMilliseconds,
      createdAt: now,
      updatedAt: now,
    ),
    PeerRow(
      id: 'mock-peer-4',
      peerId: 'mock-peer-4',
      displayName: 'Jules',
      deviceLabel: 'Tablet',
      fingerprint: 'QZ11-4R',
      relationshipState: 'accepted',
      isBlocked: false,
      lastSeenAt: null,
      createdAt: now,
      updatedAt: now,
    ),
    PeerRow(
      id: 'mock-peer-5',
      peerId: 'mock-peer-5',
      displayName: 'Mina',
      deviceLabel: 'Office Mac',
      fingerprint: 'PT08-6S',
      relationshipState: 'accepted',
      isBlocked: false,
      lastSeenAt: now - const Duration(days: 1, hours: 3).inMilliseconds,
      createdAt: now,
      updatedAt: now,
    ),
    PeerRow(
      id: 'mock-peer-6',
      peerId: 'mock-peer-6',
      displayName: 'Rico',
      deviceLabel: 'Rico\'s Desktop',
      fingerprint: 'VB54-2M',
      relationshipState: 'accepted',
      isBlocked: false,
      lastSeenAt: now - const Duration(minutes: 49).inMilliseconds,
      createdAt: now,
      updatedAt: now,
    ),
  ];
});

final reachableContactsProvider = StreamProvider((ref) {
  ref.watch(v2PresenceDiscoveryControllerProvider);
  return ref.read(peersRepositoryProvider).watchReachableAcceptedContacts();
});

final discoveredPeersProvider = StreamProvider((ref) {
  ref.watch(v2PresenceDiscoveryControllerProvider);
  return ref.read(peersRepositoryProvider).watchDiscoveredPeers();
});

final pendingIncomingRequestsProvider = StreamProvider((ref) {
  return ref.read(requestsRepositoryProvider).watchPendingIncomingRequests();
});

final pendingOutgoingRequestsProvider = StreamProvider((ref) {
  return ref.read(requestsRepositoryProvider).watchPendingOutgoingRequests();
});

final conversationListProvider = StreamProvider<List<ConversationRow>>((ref) {
  final localIdentityAsync = ref.watch(localIdentityBootstrapProvider);
  return localIdentityAsync.when(
    data: (localIdentity) {
      return ref
          .read(conversationsRepositoryProvider)
          .watchConversationList(localPeerId: localIdentity.peerId);
    },
    loading: () => Stream.value(const []),
    error: (error, stackTrace) => Stream.error(error, stackTrace),
  );
});

final previewConversationListProvider = Provider<List<ConversationRow>>((ref) {
  final now = DateTime.now();
  return [
    ConversationRow(
      id: 'mock-conversation-1',
      type: 'group',
      title: 'Weekend LAN Party',
      pinnedMessageId: null,
      lastMessagePreview: 'Bring your own headset this time.',
      lastMessageAt: now
          .subtract(const Duration(minutes: 6))
          .millisecondsSinceEpoch,
      unreadCount: 3,
      isArchived: false,
      isMuted: false,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    ),
    ConversationRow(
      id: 'mock-conversation-2',
      type: 'direct',
      title: 'Ken',
      pinnedMessageId: null,
      lastMessagePreview: 'I\'ll send the build after dinner.',
      lastMessageAt: now
          .subtract(const Duration(minutes: 18))
          .millisecondsSinceEpoch,
      unreadCount: 0,
      isArchived: false,
      isMuted: false,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    ),
    ConversationRow(
      id: 'mock-conversation-3',
      type: 'direct',
      title: 'Aira',
      pinnedMessageId: null,
      lastMessagePreview: 'Can you test on Windows too?',
      lastMessageAt: now
          .subtract(const Duration(hours: 2, minutes: 10))
          .millisecondsSinceEpoch,
      unreadCount: 1,
      isArchived: false,
      isMuted: false,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    ),
    ConversationRow(
      id: 'mock-conversation-4',
      type: 'group',
      title: 'Office Mesh',
      pinnedMessageId: null,
      lastMessagePreview: 'Printer is back online.',
      lastMessageAt: now
          .subtract(const Duration(hours: 5, minutes: 24))
          .millisecondsSinceEpoch,
      unreadCount: 0,
      isArchived: false,
      isMuted: true,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    ),
    ConversationRow(
      id: 'mock-conversation-5',
      type: 'direct',
      title: 'Marco',
      pinnedMessageId: null,
      lastMessagePreview: 'The photos transferred correctly.',
      lastMessageAt: now
          .subtract(const Duration(days: 1, hours: 1))
          .millisecondsSinceEpoch,
      unreadCount: 0,
      isArchived: false,
      isMuted: false,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    ),
    ConversationRow(
      id: 'mock-conversation-6',
      type: 'direct',
      title: 'Jules',
      pinnedMessageId: null,
      lastMessagePreview: 'Meet near the router closet.',
      lastMessageAt: now
          .subtract(const Duration(days: 3))
          .millisecondsSinceEpoch,
      unreadCount: 2,
      isArchived: false,
      isMuted: false,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    ),
  ];
});

final pendingGroupInvitesProvider = StreamProvider<List<ConversationRow>>((
  ref,
) {
  final localIdentityAsync = ref.watch(localIdentityBootstrapProvider);
  return localIdentityAsync.when(
    data: (localIdentity) {
      return ref
          .read(conversationsRepositoryProvider)
          .watchPendingGroupInvites(localPeerId: localIdentity.peerId);
    },
    loading: () => Stream.value(const []),
    error: (error, stackTrace) => Stream.error(error, stackTrace),
  );
});

final conversationStreamProvider =
    StreamProvider.family<ConversationRow?, String>((ref, conversationId) {
      return ref
          .read(conversationsRepositoryProvider)
          .watchConversationById(conversationId);
    });

final conversationDetailsProvider =
    FutureProvider.family<ConversationRow?, String>((ref, conversationId) {
      return ref
          .read(conversationsRepositoryProvider)
          .getConversationById(conversationId);
    });

final conversationMessagesProvider =
    StreamProvider.family<List<MessageRow>, String>((ref, conversationId) {
      return ref.read(messagesRepositoryProvider).watchMessages(conversationId);
    });

final messageAttachmentsProvider =
    StreamProvider.family<List<AttachmentRow>, String>((ref, messageId) {
      return ref
          .read(attachmentsRepositoryProvider)
          .watchAttachmentsForMessage(messageId);
    });

final conversationMembersProvider =
    StreamProvider.family<List<ConversationMemberRow>, String>((
      ref,
      conversationId,
    ) {
      return ref
          .read(conversationsRepositoryProvider)
          .watchConversationMembers(conversationId);
    });

final directConversationPeerProvider = FutureProvider.family<PeerRow?, String>((
  ref,
  conversationId,
) async {
  final localIdentity = await ref.read(identityServiceProvider).bootstrap();
  return ref
      .read(conversationsRepositoryProvider)
      .getDirectPeerForConversation(
        conversationId: conversationId,
        localPeerId: localIdentity.peerId,
      );
});

final conversationMemberPeersProvider =
    FutureProvider.family<List<PeerRow>, String>((ref, conversationId) {
      return ref
          .read(conversationsRepositoryProvider)
          .getConversationPeers(conversationId);
    });

class RequestActions {
  final V2RequestProtocolController _controller;

  RequestActions(this._controller);

  Future<ContactRequestRow> sendConnectionRequest({
    required String peerId,
    String? message,
  }) {
    return _controller.sendConnectionRequest(peerId: peerId, message: message);
  }

  Future<ContactRequestRow> acceptRequest(String requestId) {
    return _controller.acceptRequest(requestId);
  }

  Future<ContactRequestRow> declineRequest(String requestId) {
    return _controller.declineRequest(requestId);
  }

  Future<ContactRequestRow> cancelRequest(String requestId) {
    return _controller.cancelRequest(requestId);
  }

  Future<void> blockPeer({required String peerId, String? requestId}) {
    return _controller.blockPeer(peerId: peerId, requestId: requestId);
  }
}

final requestActionsProvider = Provider<RequestActions>((ref) {
  ref.watch(v2RequestProtocolControllerProvider);
  return RequestActions(ref.read(v2RequestProtocolControllerProvider));
});

class ConversationActions {
  final V2DirectMessageProtocolController _directController;
  final V2GroupProtocolController _groupController;
  final ConversationsRepository _conversationsRepository;
  final MessagesRepository _messagesRepository;
  final Ref _ref;

  ConversationActions(
    this._directController,
    this._groupController,
    this._conversationsRepository,
    this._messagesRepository,
    this._ref,
  );

  Future<ConversationRow> openDirectConversation({
    required String peerId,
    String? title,
  }) {
    return _directController.openDirectConversation(
      peerId: peerId,
      title: title,
    );
  }

  Future<ConversationRow> createGroupConversation({
    required String title,
    required List<String> invitedPeerIds,
  }) {
    return _groupController.createGroupConversation(
      title: title,
      invitedPeerIds: invitedPeerIds,
    );
  }

  Future<MessageRow> sendTextMessage({
    String? peerId,
    required String text,
    required String conversationId,
    String? conversationTitle,
    String? replyToMessageId,
  }) async {
    final conversation = await _conversationsRepository.getConversationById(
      conversationId,
    );
    if (conversation == null) {
      throw StateError('Conversation was not found.');
    }

    if (conversation.type == 'group') {
      return _groupController.sendGroupTextMessage(
        conversationId: conversationId,
        text: text,
        replyToMessageId: replyToMessageId,
      );
    }

    if (peerId == null) {
      throw StateError('A direct conversation requires a peer ID.');
    }

    return _directController.sendTextMessage(
      peerId: peerId,
      text: text,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
      replyToMessageId: replyToMessageId,
    );
  }

  Future<void> acceptGroupInvite(String conversationId) {
    return _groupController.acceptGroupInvite(conversationId);
  }

  Future<void> declineGroupInvite(String conversationId) {
    return _groupController.declineGroupInvite(conversationId);
  }

  Future<void> setActiveConversation(String? conversationId) async {
    _ref.read(activeConversationIdProvider.notifier).set(conversationId);
    if (conversationId != null) {
      await _conversationsRepository.markConversationRead(conversationId);
    }
    await _directController.setActiveConversation(conversationId);
  }

  Future<void> deleteMessage(String messageId) {
    return _messagesRepository.deleteMessage(messageId);
  }

  Future<void> pinMessage({
    required String conversationId,
    required String messageId,
  }) {
    return _conversationsRepository.pinMessage(
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  Future<void> clearPinnedMessage(String conversationId) {
    return _conversationsRepository.clearPinnedMessage(conversationId);
  }
}

final conversationActionsProvider = Provider<ConversationActions>((ref) {
  ref.watch(v2DirectMessageProtocolControllerProvider);
  ref.watch(v2GroupProtocolControllerProvider);
  return ConversationActions(
    ref.read(v2DirectMessageProtocolControllerProvider),
    ref.read(v2GroupProtocolControllerProvider),
    ref.read(conversationsRepositoryProvider),
    ref.read(messagesRepositoryProvider),
    ref,
  );
});

class MediaActions {
  final V2MediaProtocolNotifier _notifier;

  MediaActions(this._notifier);

  Future<void> sendFile({
    required String peerId,
    required String conversationId,
    required String conversationTitle,
    required String filePath,
  }) {
    return _notifier.sendFile(
      peerId: peerId,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
      filePath: filePath,
    );
  }

  Future<void> acceptFile({
    required String peerId,
    required String attachmentId,
  }) {
    return _notifier.acceptFile(peerId: peerId, attachmentId: attachmentId);
  }

  Future<void> cancelFileTransfer({
    required String peerId,
    required String attachmentId,
  }) {
    return _notifier.cancelFileTransfer(
      peerId: peerId,
      attachmentId: attachmentId,
    );
  }

  Future<void> prepareOutgoingCall({
    required String peerId,
    required String conversationId,
    required String conversationTitle,
    required String callType,
  }) {
    return _notifier.prepareOutgoingCall(
      peerId: peerId,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
      callType: callType,
    );
  }

  Future<void> addLocalCallSummary({
    required String conversationId,
    required String callType,
    required int durationSeconds,
  }) {
    return _notifier.addLocalCallSummary(
      conversationId: conversationId,
      callType: callType,
      durationSeconds: durationSeconds,
    );
  }

  Future<void> clearIncomingCall() {
    return _notifier.clearIncomingCall();
  }

  Future<void> declineIncomingCall(V2IncomingCall call) {
    return _notifier.declineIncomingCall(call);
  }

  Future<void> clearNotice() {
    return _notifier.clearNotice();
  }

  Future<void> sendCallSignal({
    required String peerId,
    String? conversationId,
    String? conversationTitle,
    required String payload,
  }) {
    return _notifier.sendCallSignal(
      peerId: peerId,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
      payload: payload,
    );
  }
}

final mediaActionsProvider = Provider<MediaActions>((ref) {
  ref.watch(v2MediaProtocolProvider);
  return MediaActions(ref.read(v2MediaProtocolProvider.notifier));
});
