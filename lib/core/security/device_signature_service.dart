import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'secret_store.dart';

class DeviceSigningIdentity {
  final String publicKey;

  const DeviceSigningIdentity({required this.publicKey});
}

class DeviceSignatureService {
  static const _privateKeyStoreKey = 'lanline_signing_private_key';
  static const _publicKeyStoreKey = 'lanline_signing_public_key';

  final SecretStore _secretStore;
  final Ed25519 _algorithm;
  final Random _random;

  DeviceSignatureService(
    this._secretStore, {
    Ed25519? algorithm,
    Random? random,
  }) : _algorithm = algorithm ?? Ed25519(),
       _random = random ?? Random.secure();

  Future<DeviceSigningIdentity> ensureIdentity() async {
    final existingPublicKey = await _secretStore.read(_publicKeyStoreKey);
    final existingPrivateKey = await _secretStore.read(_privateKeyStoreKey);
    if (existingPublicKey != null && existingPrivateKey != null) {
      return DeviceSigningIdentity(publicKey: existingPublicKey);
    }

    final seed = List<int>.generate(32, (_) => _random.nextInt(256));
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    final publicKeyBase64 = base64Encode(publicKey.bytes);
    final privateKeyBase64 = base64Encode(seed);

    await _secretStore.write(_privateKeyStoreKey, privateKeyBase64);
    await _secretStore.write(_publicKeyStoreKey, publicKeyBase64);

    return DeviceSigningIdentity(publicKey: publicKeyBase64);
  }

  Future<String> signPayload(Map<String, dynamic> payload) async {
    final seedBase64 = await _secretStore.read(_privateKeyStoreKey);
    if (seedBase64 == null) {
      throw StateError('Signing identity is not initialized.');
    }
    final seed = base64Decode(seedBase64);
    final keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final signature = await _algorithm.sign(
      utf8.encode(canonicalJson(payload)),
      keyPair: keyPair,
    );
    return base64Encode(signature.bytes);
  }

  Future<bool> verifyPayload({
    required Map<String, dynamic> payload,
    required String publicKeyBase64,
    required String signatureBase64,
  }) async {
    try {
      final publicKey = SimplePublicKey(
        base64Decode(publicKeyBase64),
        type: KeyPairType.ed25519,
      );
      final signature = Signature(
        base64Decode(signatureBase64),
        publicKey: publicKey,
      );
      return _algorithm.verify(
        utf8.encode(canonicalJson(payload)),
        signature: signature,
      );
    } catch (_) {
      return false;
    }
  }
}

String canonicalJson(Object? value) {
  if (value == null) return 'null';
  if (value is String) {
    return jsonEncode(value);
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  if (value is List) {
    return '[${value.map(canonicalJson).join(',')}]';
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${canonicalJson(value[key])}').join(',')}}';
  }
  return jsonEncode(value.toString());
}
