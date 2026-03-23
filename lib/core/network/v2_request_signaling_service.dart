import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final v2RequestSignalingServiceProvider = Provider<V2RequestSignalingService>((
  ref,
) {
  return V2RequestSignalingService();
});

class V2RequestSignalingService {
  static const int defaultPort = 55557;

  HttpServer? _server;
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();

  Stream<String> get onMessageReceived => _messageController.stream;

  Future<void> startServer({int port = defaultPort, String? bindAddress}) async {
    if (_server != null) return;

    try {
      final address = bindAddress != null
          ? InternetAddress(bindAddress)
          : InternetAddress.anyIPv4;

      _server = await HttpServer.bind(address, port, shared: true);
      _server?.listen((request) async {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }

        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen(
          (message) {
            if (!_messageController.isClosed) {
              _messageController.add(message.toString());
            }
          },
          onError: (Object error) {
            debugPrint(
              '[V2RequestSignalingService] Incoming socket error: $error',
            );
          },
        );
      });
    } catch (error) {
      debugPrint(
        '[V2RequestSignalingService] Failed to start server on port $port: '
        '$error',
      );
    }
  }

  Future<void> sendMessage({
    required String host,
    int port = defaultPort,
    required String payload,
  }) async {
    WebSocket? socket;

    try {
      socket = await WebSocket.connect('ws://$host:$port');
      socket.add(payload);
      await socket.close();
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  Future<void> stopServer() async {
    await _server?.close(force: true);
    _server = null;
  }
}
