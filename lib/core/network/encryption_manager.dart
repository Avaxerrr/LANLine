import 'package:encrypt/encrypt.dart';

class EncryptionManager {
  static final EncryptionManager _instance = EncryptionManager._internal();
  factory EncryptionManager() => _instance;
  EncryptionManager._internal();

  Key? _aesKey;
  IV? _iv;
  Encrypter? _encrypter;

  void setPassword(String password) {
    // Basic 256-bit AES key derivation using straightforward padding for LAN sync
    final paddedPassword = password.padRight(32, '0').substring(0, 32);
    _aesKey = Key.fromUtf8(paddedPassword);
    _iv = IV.fromLength(16);
    _encrypter = Encrypter(AES(_aesKey!));
  }

  String encrypt(String plainText) {
    if (_encrypter == null) return plainText; // Not securely joined yet
    return _encrypter!.encrypt(plainText, iv: _iv!).base64;
  }

  String decrypt(String base64Text) {
    if (_encrypter == null) return base64Text;
    try {
      return _encrypter!.decrypt64(base64Text, iv: _iv!);
    } catch (e) {
      return '{"type":"message", "sender":"System", "text":"[Encrypted Packet Unreadable]"}';
    }
  }
}
