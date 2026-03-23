import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
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
