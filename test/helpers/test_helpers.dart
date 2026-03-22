import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanline/core/network/websocket_server.dart';
import 'package:lanline/core/network/websocket_client.dart';
import 'package:lanline/core/network/file_transfer_manager.dart';
import 'package:lanline/core/network/discovery_service.dart';
// username_provider import available when needed for SharedPreferences setup

// ── Mock Services ──────────────────────────────────────────────

class MockWebSocketServer extends Mock implements WebSocketServerService {}

class MockWebSocketClient extends Mock implements WebSocketClientService {}

class MockFileTransferManager extends Mock implements FileTransferManager {}

class MockDiscoveryService extends Mock implements DiscoveryService {}

// ── Test Container Builder ─────────────────────────────────────

/// Creates a [ProviderContainer] with all external services mocked out.
///
/// Use this in unit tests for notifiers so they never touch real
/// WebSockets, file I/O, or SharedPreferences.
///
/// Returns a record with the container and all mocks for easy stubbing.
({
  ProviderContainer container,
  MockWebSocketServer server,
  MockWebSocketClient client,
  MockFileTransferManager fileTransfer,
  MockDiscoveryService discovery,
}) createTestContainer({
  String username = 'TestUser',
}) {
  final server = MockWebSocketServer();
  final client = MockWebSocketClient();
  final fileTransfer = MockFileTransferManager();
  final discovery = MockDiscoveryService();

  // Default stubs so tests don't crash on common calls
  when(() => server.onMessageReceived).thenReturn(const Stream.empty());
  when(() => server.onParticipantCountChanged).thenReturn(const Stream.empty());
  when(() => server.participantNames).thenReturn([]);
  when(() => server.clientCount).thenReturn(0);
  when(() => server.broadcastMessage(any())).thenReturn(null);

  when(() => client.onMessageReceived).thenReturn(const Stream.empty());
  when(() => client.isConnected).thenReturn(true);
  when(() => client.sendMessage(any())).thenReturn(null);

  // SharedPreferences with username pre-set
  SharedPreferences.setMockInitialValues({
    'lanline_username': username,
  });

  final container = ProviderContainer(
    overrides: [
      webSocketServerProvider.overrideWithValue(server),
      webSocketClientProvider.overrideWithValue(client),
      fileTransferProvider.overrideWithValue(fileTransfer),
      discoveryServiceProvider.overrideWithValue(discovery),
    ],
  );

  return (
    container: container,
    server: server,
    client: client,
    fileTransfer: fileTransfer,
    discovery: discovery,
  );
}
