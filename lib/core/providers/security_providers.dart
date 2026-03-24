import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../security/device_signature_service.dart';
import '../security/flutter_secret_store.dart';
import '../security/local_data_protection_service.dart';
import '../security/secret_store.dart';

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final secretStoreProvider = Provider<SecretStore>((ref) {
  return FlutterSecretStore(ref.read(flutterSecureStorageProvider));
});

final deviceSignatureServiceProvider = Provider<DeviceSignatureService>((ref) {
  return DeviceSignatureService(ref.read(secretStoreProvider));
});

final localDataProtectionServiceProvider =
    Provider<LocalDataProtectionService>((ref) {
      return EncryptedLocalDataProtectionService(ref.read(secretStoreProvider));
    });
