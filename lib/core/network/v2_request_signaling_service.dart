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
  static const int _maxBindRetries = 4;
  static const Duration _bindRetryDelay = Duration(seconds: 2);

  HttpServer? _server;
  final StreamController<String> _messageController =
      StreamController<String>.broadcast();
  final List<Future<bool> Function(HttpRequest request)> _httpHandlers = [];

  Stream<String> get onMessageReceived => _messageController.stream;

  void registerHttpHandler(Future<bool> Function(HttpRequest request) handler) {
    if (_httpHandlers.contains(handler)) return;
    _httpHandlers.add(handler);
  }

  void unregisterHttpHandler(
    Future<bool> Function(HttpRequest request) handler,
  ) {
    _httpHandlers.remove(handler);
  }

  Future<void> startServer({
    int port = defaultPort,
    String? bindAddress,
  }) async {
    if (_server != null) return;

    final address = bindAddress != null
        ? InternetAddress(bindAddress)
        : InternetAddress.anyIPv4;

    // Retry binding in case the port is still held by a previous instance.
    for (var attempt = 1; attempt <= _maxBindRetries; attempt++) {
      try {
        _server = await HttpServer.bind(address, port, shared: true);
        break;
      } catch (error) {
        if (attempt < _maxBindRetries) {
          debugPrint(
            '[V2RequestSignalingService] Port $port busy, '
            'retry $attempt/$_maxBindRetries in ${_bindRetryDelay.inSeconds}s',
          );
          await Future.delayed(_bindRetryDelay);
        } else {
          debugPrint(
            '[V2RequestSignalingService] Failed to start server on port $port '
            'after $_maxBindRetries attempts: $error',
          );
          return;
        }
      }
    }

    _server?.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        for (final handler in List.of(_httpHandlers)) {
          final handled = await handler(request);
          if (handled) {
            return;
          }
        }

        request.response.statusCode = HttpStatus.notFound;
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
      socket = await WebSocket.connect(
        'ws://$normalizedHost:$port',
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException(
          'Connection to $normalizedHost:$port timed out after 10s',
        ),
      );
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
