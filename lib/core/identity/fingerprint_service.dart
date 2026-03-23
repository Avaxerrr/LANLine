import 'package:crypto/crypto.dart';

class FingerprintService {
  static String fromPeerId(String peerId) {
    final digest = sha1.convert(peerId.codeUnits).toString().toUpperCase();
    return '${digest.substring(0, 4)}-${digest.substring(4, 6)}';
  }
}
