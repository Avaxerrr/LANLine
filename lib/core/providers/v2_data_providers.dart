import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../repositories/requests_repository.dart';
import 'v2_presence_discovery_provider.dart';
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
  final RequestsRepository _repository;

  RequestActions(this._repository);

  Future<ContactRequestRow> sendConnectionRequest({
    required String peerId,
    String? message,
  }) {
    return _repository.sendConnectionRequest(peerId: peerId, message: message);
  }

  Future<ContactRequestRow> acceptRequest(String requestId) {
    return _repository.acceptRequest(requestId);
  }

  Future<ContactRequestRow> declineRequest(String requestId) {
    return _repository.declineRequest(requestId);
  }

  Future<ContactRequestRow> cancelRequest(String requestId) {
    return _repository.cancelRequest(requestId);
  }

  Future<void> blockPeer({required String peerId, String? requestId}) {
    return _repository.blockPeer(peerId: peerId, requestId: requestId);
  }
}

final requestActionsProvider = Provider<RequestActions>((ref) {
  return RequestActions(ref.read(requestsRepositoryProvider));
});
