import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanline/core/network/encryption_manager.dart';

final webSocketClientProvider = Provider<WebSocketClientService>((ref) {
  return WebSocketClientService();
});

class WebSocketClientService {
  WebSocket? _socket;
  
  var _messageController = StreamController<String>.broadcast();
  Stream<String> get onMessageReceived => _messageController.stream;

  bool get isConnected => _socket != null && _socket!.readyState == WebSocket.open;

  Future<void> connect(String ipAddress, {int port = 55556}) async {
    // Always close stale connections first
    disconnect();
    _messageController = StreamController<String>.broadcast();
    try {
      _socket = await WebSocket.connect('ws://$ipAddress:$port');
      
      _socket?.listen(
        (message) {
          final decrypted = EncryptionManager().decrypt(message.toString());
          if (!_messageController.isClosed) {
            _messageController.add(decrypted);
          }
        },
        onDone: () {
          _socket = null;
        },
        onError: (e) {
          _socket = null;
        }
      );
    } catch (e) {
      // Ignored
    }
  }

  void sendMessage(String message) {
    if (isConnected) {
      final encrypted = EncryptionManager().encrypt(message);
      _socket?.add(encrypted);
    }
  }

  void disconnect() {
    try { _socket?.close(); } catch (_) {}
    _socket = null;
    if (!_messageController.isClosed) {
      _messageController.close();
    }
  }
}
