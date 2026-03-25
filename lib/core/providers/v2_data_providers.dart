import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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

final conversationMessagePageSizeProvider = StateProvider.family<int, String>(
  (ref, conversationId) => 50,
);

final contactsProvider = StreamProvider((ref) {
  ref.watch(v2PresenceDiscoveryControllerProvider);
  return ref.read(peersRepositoryProvider).watchAcceptedContacts();
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
      final limit = ref.watch(
        conversationMessagePageSizeProvider(conversationId),
      );
      return ref
          .read(messagesRepositoryProvider)
          .watchMessagesPage(conversationId, limit: limit);
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
    String? senderPeerId,
  }) {
    return _notifier.addLocalCallSummary(
      conversationId: conversationId,
      callType: callType,
      durationSeconds: durationSeconds,
      senderPeerId: senderPeerId,
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
