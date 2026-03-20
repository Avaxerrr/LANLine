import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

class EncryptionManager {
  static final EncryptionManager _instance = EncryptionManager._internal();
  factory EncryptionManager() => _instance;
  EncryptionManager._internal();

  Key? _aesKey;
  IV? _iv;
  Encrypter? _encrypter;

  bool get isEnabled => _encrypter != null;

  void setPassword(String password) {
    // Deterministic SHA-256 key derivation — guarantees both sides get the exact same 32 bytes
    final hash = sha256.convert(utf8.encode(password));
    _aesKey = Key.fromBase16(hash.toString());
    _iv = IV.fromLength(16);
    _encrypter = Encrypter(AES(_aesKey!));
  }

  void clearPassword() {
    _aesKey = null;
    _iv = null;
    _encrypter = null;
  }

  String encrypt(String plainText) {
    if (_encrypter == null) return plainText;
    return _encrypter!.encrypt(plainText, iv: _iv!).base64;
  }

  String decrypt(String base64Text) {
    if (_encrypter == null) return base64Text;
    try {
      return _encrypter!.decrypt64(base64Text, iv: _iv!);
    } catch (e) {
      return '{"type":"error", "sender":"System", "text":"[Encrypted Packet Unreadable: Password Mismatch!]"}';
    }
  }
}
