import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/attachments_repository.dart';
import '../repositories/conversations_repository.dart';
import '../repositories/identity_repository.dart';
import '../repositories/messages_repository.dart';
import '../repositories/peers_repository.dart';
import '../repositories/requests_repository.dart';
import 'message_retention_provider.dart';
import 'security_providers.dart';
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
  return ConversationsRepository(
    ref.read(appDatabaseProvider),
    dataProtectionService: ref.read(localDataProtectionServiceProvider),
  );
});

final attachmentsRepositoryProvider = Provider<AttachmentsRepository>((ref) {
  return AttachmentsRepository(ref.read(appDatabaseProvider));
});

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  return MessagesRepository(
    ref.read(appDatabaseProvider),
    conversationsRepository: ref.read(conversationsRepositoryProvider),
    attachmentsRepository: ref.read(attachmentsRepositoryProvider),
    dataProtectionService: ref.read(localDataProtectionServiceProvider),
    readRetentionLimit: () => ref.read(messageRetentionLimitProvider),
  );
});
