import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'v2_repository_providers.dart';

final contactsProvider = StreamProvider((ref) {
  return ref.read(peersRepositoryProvider).watchAcceptedContacts();
});

final discoveredPeersProvider = StreamProvider((ref) {
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
