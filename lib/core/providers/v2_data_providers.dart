import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'v2_direct_message_protocol_provider.dart';
import 'v2_identity_provider.dart';
import 'v2_media_protocol_provider.dart';
import 'v2_navigation_state_provider.dart';
import 'v2_presence_discovery_provider.dart';
import 'v2_request_protocol_provider.dart';
import 'v2_repository_providers.dart';

final contactsProvider = StreamProvider((ref) {
  ref.watch(v2PresenceDiscoveryControllerProvider);
  return ref.read(peersRepositoryProvider).watchAcceptedContacts();
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

final conversationListProvider = StreamProvider((ref) {
  return ref.read(conversationsRepositoryProvider).watchConversationList();
});

final conversationMessagesProvider = StreamProvider.family<
  List<MessageRow>,
  String
>((ref, conversationId) {
  return ref.read(messagesRepositoryProvider).watchMessages(conversationId);
});

final messageAttachmentsProvider =
    StreamProvider.family<List<AttachmentRow>, String>((ref, messageId) {
      return ref
          .read(attachmentsRepositoryProvider)
          .watchAttachmentsForMessage(messageId);
    });

final directConversationPeerProvider = FutureProvider.family<PeerRow?, String>((
  ref,
  conversationId,
) async {
  final localIdentity = await ref.read(identityServiceProvider).bootstrap();
  return ref.read(conversationsRepositoryProvider).getDirectPeerForConversation(
    conversationId: conversationId,
    localPeerId: localIdentity.peerId,
  );
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
  final V2DirectMessageProtocolController _controller;
  final Ref _ref;

  ConversationActions(this._controller, this._ref);

  Future<ConversationRow> openDirectConversation({
    required String peerId,
    String? title,
  }) {
    return _controller.openDirectConversation(peerId: peerId, title: title);
  }

  Future<MessageRow> sendTextMessage({
    required String peerId,
    required String text,
    String? conversationId,
    String? conversationTitle,
  }) {
    return _controller.sendTextMessage(
      peerId: peerId,
      text: text,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
    );
  }

  Future<void> setActiveConversation(String? conversationId) {
    _ref.read(activeConversationIdProvider.notifier).set(conversationId);
    return _controller.setActiveConversation(conversationId);
  }
}

final conversationActionsProvider = Provider<ConversationActions>((ref) {
  ref.watch(v2DirectMessageProtocolControllerProvider);
  return ConversationActions(
    ref.read(v2DirectMessageProtocolControllerProvider),
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
