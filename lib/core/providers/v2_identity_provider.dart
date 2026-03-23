import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../identity/identity_service.dart';
import 'username_provider.dart';
import 'v2_repository_providers.dart';

final identityServiceProvider = Provider<IdentityService>((ref) {
  return IdentityService(
    repository: ref.read(identityRepositoryProvider),
    prefs: ref.read(sharedPreferencesProvider),
  );
});

final localIdentityProvider = StreamProvider((ref) {
  return ref.read(identityRepositoryProvider).watchLocalIdentity();
});

final localIdentityBootstrapProvider = FutureProvider((ref) async {
  return ref.read(identityServiceProvider).bootstrap();
});
