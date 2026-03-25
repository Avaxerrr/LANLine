import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'protocol_validation.dart';

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

  Future<void> startServer({
    int port = defaultPort,
    String? bindAddress,
  }) async {
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
            // Check raw size before decoding to avoid processing oversized payloads
            if (message is List<int> &&
                message.length > kMaxProtocolPayloadBytes) {
              unawaited(socket.close(WebSocketStatus.messageTooBig));
              return;
            }
            final text = switch (message) {
              String value => value,
              List<int> value => String.fromCharCodes(value),
              _ => null,
            };
            if (text == null || text.length > kMaxProtocolPayloadBytes) {
              unawaited(socket.close(WebSocketStatus.messageTooBig));
              return;
            }
            if (!_messageController.isClosed) {
              _messageController.add(text);
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
    final normalizedHost = host.trim();
    if (normalizedHost.isEmpty) {
      throw StateError('Host must not be empty.');
    }
    if (!isValidProtocolPort(port)) {
      throw StateError('Port $port is outside the valid TCP range.');
    }
    if (payload.length > kMaxProtocolPayloadBytes) {
      throw StateError('Payload exceeds the signaling size limit.');
    }

    WebSocket? socket;

    try {
      socket = await WebSocket.connect('ws://$normalizedHost:$port');
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
