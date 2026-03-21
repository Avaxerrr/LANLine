import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lanline/core/network/encryption_manager.dart';

final webSocketServerProvider = Provider<WebSocketServerService>((ref) {
  return WebSocketServerService();
});

class WebSocketServerService {
  HttpServer? _server;
  final List<WebSocket> _clients = [];
  final Map<WebSocket, String> _clientNames = {};

  final _messageController = StreamController<String>.broadcast();
  Stream<String> get onMessageReceived => _messageController.stream;

  // Participant count tracking
  final _participantController = StreamController<int>.broadcast();
  Stream<int> get onParticipantCountChanged => _participantController.stream;
  int get clientCount => _clients.length;

  /// Returns the list of connected participant display names
  List<String> get participantNames => _clientNames.values.toList();

  Future<void> startServer({int port = 55556, String? bindAddress}) async {
    // Close existing server if it was already running (e.g. after hot reload)
    await _server?.close(force: true);

    final address = bindAddress != null
        ? InternetAddress(bindAddress)
        : InternetAddress.anyIPv4;

    // shared: true allows hot-reloads to bind to the same port without crashing
    _server = await HttpServer.bind(address, port, shared: true);
    _server?.listen((HttpRequest request) async {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        _clients.add(socket);
        _notifyParticipantChange();

        socket.listen(
          (message) {
            final decrypted = EncryptionManager().decrypt(message.toString());

            try {
              final data = jsonDecode(decrypted);
              if (data['type'] == 'handshake') {
                final ack = jsonEncode({'type': 'handshake_ack'});
                socket.add(EncryptionManager().encrypt(ack));
                return; // Do NOT broadcast handshake to Chatroom
              } else if (data['type'] == 'error') {
                socket.add(EncryptionManager().encrypt(jsonEncode({'type': 'error', 'text': 'Wrong password'})));
                return; // Do NOT spam the Host's Chatroom
              } else if (data['type'] == 'join') {
                final sender = data['sender'] as String? ?? 'Unknown';
                _clientNames[socket] = sender;
                _notifyParticipantChange();
                return; // Don't show join as a chat message
              }
            } catch (e) {
              // Ignore
            }

            _messageController.add(decrypted);

            // Broadcast raw encrypted packet to other clients securely
            for (var client in _clients) {
              if (client != socket && client.readyState == WebSocket.open) {
                client.add(message.toString());
              }
            }
          },
          onDone: () {
            _clientNames.remove(socket);
            _clients.remove(socket);
            _notifyParticipantChange();
          },
          onError: (e) {
            _clientNames.remove(socket);
            _clients.remove(socket);
            _notifyParticipantChange();
          },
        );
      }
    });
  }

  void _notifyParticipantChange() {
    _participantController.add(_clients.length);

    // Broadcast participant count + names to all connected clients
    final payload = jsonEncode({
      'type': 'participant_list',
      'count': _clients.length + 1, // +1 to include the host
      'names': _clientNames.values.toList(),
    });
    broadcastMessage(payload);
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
    _clientNames.clear();
    _server?.close(force: true);
    _messageController.close();
    _participantController.close();
  }
}
