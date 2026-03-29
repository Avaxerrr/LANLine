import 'dart:convert';

import '../db/app_database.dart';
import '../security/device_signature_service.dart';
import 'protocol_validation.dart';

/// Builds and verifies signed protocol payloads.
///
/// Shared by group and direct-message protocol controllers to avoid
/// duplicating signing/verification logic.
class ProtocolSigning {
  final DeviceSignatureService _deviceSignatureService;

  const ProtocolSigning(this._deviceSignatureService);

  Future<String> buildSignedPayload(
    Map<String, dynamic> payload, {
    required LocalIdentityRow localIdentity,
  }) async {
    final signingPublicKey =
        localIdentity.signingPublicKey ??
        (await _deviceSignatureService.ensureIdentity()).publicKey;
    final signature = await _deviceSignatureService.signPayload(payload);
    return jsonEncode({
      ...payload,
      'senderSigningPublicKey': signingPublicKey,
      'signature': signature,
    });
  }

  Future<bool> verifySignedPayload(
    Map<String, dynamic> payload, {
    required String? fallbackPublicKey,
  }) async {
    final signature = payload['signature']?.toString();
    final publicKey =
        payload['senderSigningPublicKey']?.toString() ?? fallbackPublicKey;
    if (signature == null ||
        publicKey == null ||
        !isValidOptionalProtocolText(
          signature,
          maxLength: kMaxProtocolSignatureLength,
        ) ||
        !isValidOptionalProtocolText(
          publicKey,
          maxLength: kMaxProtocolSigningPublicKeyLength,
        )) {
      return false;
    }
    final signedPayload = Map<String, dynamic>.from(payload)
      ..remove('signature')
      ..remove('senderSigningPublicKey');
    return _deviceSignatureService.verifyPayload(
      payload: signedPayload,
      publicKeyBase64: publicKey,
      signatureBase64: signature,
    );
  }
}
