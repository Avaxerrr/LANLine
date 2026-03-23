import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/attachments_repository.dart';
import '../repositories/conversations_repository.dart';
import '../repositories/identity_repository.dart';
import '../repositories/messages_repository.dart';
import '../repositories/peers_repository.dart';
import '../repositories/requests_repository.dart';
import 'v2_database_provider.dart';

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  return IdentityRepository(ref.read(appDatabaseProvider));
});

final peersRepositoryProvider = Provider<PeersRepository>((ref) {
  return PeersRepository(ref.read(appDatabaseProvider));
});

final requestsRepositoryProvider = Provider<RequestsRepository>((ref) {
  return RequestsRepository(ref.read(appDatabaseProvider));
});

final conversationsRepositoryProvider = Provider<ConversationsRepository>((
  ref,
) {
  return ConversationsRepository(ref.read(appDatabaseProvider));
});

final attachmentsRepositoryProvider = Provider<AttachmentsRepository>((ref) {
  return AttachmentsRepository(ref.read(appDatabaseProvider));
});

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepository(
    ref.read(appDatabaseProvider),
    conversationsRepository: ref.read(conversationsRepositoryProvider),
  );
});
