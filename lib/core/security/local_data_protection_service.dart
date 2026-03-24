import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'secret_store.dart';

abstract class LocalDataProtectionService {
  Future<String?> encryptNullable(String? value);
  Future<String?> decryptNullable(String? value);
}

class EncryptedLocalDataProtectionService implements LocalDataProtectionService {
  static const _storageKey = 'lanline_data_encryption_key_v1';
  static const _prefix = 'enc:v1';

  final SecretStore _secretStore;
  final AesGcm _algorithm;
  final Random _random;

  EncryptedLocalDataProtectionService(
    this._secretStore, {
    AesGcm? algorithm,
    Random? random,
  }) : _algorithm = algorithm ?? AesGcm.with256bits(),
       _random = random ?? Random.secure();

  @override
  Future<String?> encryptNullable(String? value) async {
    if (value == null || value.isEmpty) return value;
    if (value.startsWith('$_prefix:')) return value;

    final secretKey = await _loadOrCreateKey();
    final nonce = List<int>.generate(12, (_) => _random.nextInt(256));
    final secretBox = await _algorithm.encrypt(
      utf8.encode(value),
      secretKey: secretKey,
      nonce: nonce,
    );
    return [
      _prefix,
      base64Encode(secretBox.nonce),
      base64Encode(secretBox.cipherText),
      base64Encode(secretBox.mac.bytes),
    ].join(':');
  }

  @override
  Future<String?> decryptNullable(String? value) async {
    if (value == null || value.isEmpty) return value;
    if (!value.startsWith('$_prefix:')) return value;

    final parts = value.split(':');
    if (parts.length != 5) {
      return '[Encrypted content unreadable]';
    }

    try {
      final secretKey = await _loadOrCreateKey();
      final secretBox = SecretBox(
        base64Decode(parts[3]),
        nonce: base64Decode(parts[2]),
        mac: Mac(base64Decode(parts[4])),
      );
      final clearText = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return utf8.decode(clearText);
    } catch (_) {
      return '[Encrypted content unreadable]';
    }
  }

  Future<SecretKey> _loadOrCreateKey() async {
    final existing = await _secretStore.read(_storageKey);
    if (existing != null) {
      return SecretKey(base64Decode(existing));
    }

    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final encoded = base64Encode(bytes);
    await _secretStore.write(_storageKey, encoded);
    return SecretKey(bytes);
  }
}

class PassthroughLocalDataProtectionService implements LocalDataProtectionService {
  const PassthroughLocalDataProtectionService();

  @override
  Future<String?> decryptNullable(String? value) async => value;

  @override
  Future<String?> encryptNullable(String? value) async => value;
}
