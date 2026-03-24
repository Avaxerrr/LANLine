import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/device_signature_service.dart';
import '../security/local_data_protection_service.dart';
import '../security/secret_store.dart';
import '../security/shared_preferences_secret_store.dart';
import 'username_provider.dart';

final secretStoreProvider = Provider<SecretStore>((ref) {
  return SharedPreferencesSecretStore(ref.read(sharedPreferencesProvider));
});

final deviceSignatureServiceProvider = Provider<DeviceSignatureService>((ref) {
  return DeviceSignatureService(ref.read(secretStoreProvider));
});

final localDataProtectionServiceProvider = Provider<LocalDataProtectionService>(
  (ref) {
    return EncryptedLocalDataProtectionService(ref.read(secretStoreProvider));
  },
);
