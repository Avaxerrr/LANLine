import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanline/core/network/encryption_manager.dart';

final webSocketServerProvider = Provider<WebSocketServerService>((ref) {
  return WebSocketServerService();
});

class WebSocketServerService {
  HttpServer? _server;
  final int _port = 55556;
  final List<WebSocket> _clients = [];
  
  final _messageController = StreamController<String>.broadcast();
  Stream<String> get onMessageReceived => _messageController.stream;

  Future<void> startServer() async {
    // Close existing server if it was already running (e.g. after hot reload)
    await _server?.close(force: true);
    
    // shared: true allows hot-reloads to bind to the same port without crashing
    _server = await HttpServer.bind(InternetAddress.anyIPv4, _port, shared: true);
    _server?.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _clients.add(socket);
        
        socket.listen(
          (message) {
            final decrypted = EncryptionManager().decrypt(message.toString());
            _messageController.add(decrypted);
            
            // Broadcast raw encrypted packet to other clients securely
            for (var client in _clients) {
              if (client != socket && client.readyState == WebSocket.open) {
                client.add(message.toString());
              }
            }
          },
          onDone: () {
            _clients.remove(socket);
          },
          onError: (e) {
            _clients.remove(socket);
          }
        );
      }
    });
  }

  void broadcastMessage(String message) {
    final encrypted = EncryptionManager().encrypt(message);
    for (var client in _clients) {
      if (client.readyState == WebSocket.open) {
        client.add(encrypted);
      }
    }
  }

  void stopServer() {
    for (var client in _clients) {
      client.close();
    }
    _clients.clear();
    _server?.close(force: true);
    _messageController.close();
  }
}
