import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../repositories/identity_repository.dart';
import '../security/device_signature_service.dart';
import 'fingerprint_service.dart';

class IdentityService {
  static const legacyUsernameKey = 'lanline_username';
  static const defaultDisplayName = 'LANLine User';

  final IdentityRepository _repository;
  final SharedPreferences _prefs;
  final DeviceSignatureService _signatureService;
  final Uuid _uuid;

  IdentityService({
    required IdentityRepository repository,
    required SharedPreferences prefs,
    required DeviceSignatureService signatureService,
    Uuid? uuid,
  }) : _repository = repository,
       _prefs = prefs,
       _signatureService = signatureService,
       _uuid = uuid ?? const Uuid();

  Future<LocalIdentityRow> bootstrap() async {
    final existing = await _repository.getLocalIdentity();
    final legacyName = _prefs.getString(legacyUsernameKey)?.trim();
    final seededName = (legacyName != null && legacyName.isNotEmpty)
        ? legacyName
        : defaultDisplayName;
    final signingIdentity = await _signatureService.ensureIdentity();

    if (existing == null) {
      final peerId = _uuid.v4();
      return _repository.createIdentity(
        id: 'local_identity',
        peerId: peerId,
        displayName: seededName,
        fingerprint: FingerprintService.fromPeerId(peerId),
        signingPublicKey: signingIdentity.publicKey,
      );
    }

    if (existing.signingPublicKey != signingIdentity.publicKey) {
      return _repository.updateIdentity(
        id: existing.id,
        displayName: legacyName != null &&
                legacyName.isNotEmpty &&
                legacyName != existing.displayName
            ? legacyName
            : existing.displayName,
        deviceLabel: existing.deviceLabel,
        signingPublicKey: signingIdentity.publicKey,
      );
    }

    if (legacyName != null &&
        legacyName.isNotEmpty &&
        legacyName != existing.displayName) {
      return _repository.updateIdentity(
        id: existing.id,
        displayName: legacyName,
        deviceLabel: existing.deviceLabel,
        signingPublicKey: existing.signingPublicKey,
      );
    }

    return existing;
  }

  Future<LocalIdentityRow> updateProfile({
    required String displayName,
    String? deviceLabel,
  }) async {
    final existing = await _repository.getLocalIdentity();
    if (existing == null) {
      return bootstrap();
    }

    return _repository.updateIdentity(
      id: existing.id,
      displayName: displayName,
      deviceLabel: deviceLabel,
      signingPublicKey: existing.signingPublicKey,
    );
  }
}
