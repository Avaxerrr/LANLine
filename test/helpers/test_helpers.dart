import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanline/core/network/websocket_server.dart';
import 'package:lanline/core/network/websocket_client.dart';
import 'package:lanline/core/network/file_transfer_manager.dart';
import 'package:lanline/core/network/discovery_service.dart';
import 'package:lanline/core/network/webrtc_call_service.dart';
import 'package:lanline/core/providers/username_provider.dart';

// ── Mock Services ──────────────────────────────────────────────

class MockWebSocketServer extends Mock implements WebSocketServerService {}

/// Mock client that stores the onDisconnected callback so tests can invoke it.
class MockWebSocketClient extends Mock implements WebSocketClientService {
  @override
  void Function()? onDisconnected;
}

class MockFileTransferManager extends Mock implements FileTransferManager {}

class MockDiscoveryService extends Mock implements DiscoveryService {}

/// Mock call service with real fields for state and participants.
class MockWebRtcCallService extends Mock implements WebRtcCallService {
  @override
  CallState state = CallState.idle;

  @override
  final Set<String> callParticipants = {};

  @override
  void Function(String participant, bool joined)? onParticipantChanged;
}

// ── Test Container Builder ─────────────────────────────────────

/// Creates a [ProviderContainer] with all external services mocked out.
///
/// Use this in unit tests for notifiers so they never touch real
/// WebSockets, file I/O, or SharedPreferences.
///
/// Returns a record with the container and all mocks for easy stubbing.
Future<({
  ProviderContainer container,
  MockWebSocketServer server,
  MockWebSocketClient client,
  MockFileTransferManager fileTransfer,
  MockDiscoveryService discovery,
  MockWebRtcCallService callService,
})> createTestContainer({
  String username = 'TestUser',
}) async {
  final server = MockWebSocketServer();
  final client = MockWebSocketClient();
  final fileTransfer = MockFileTransferManager();
  final discovery = MockDiscoveryService();
  final callService = MockWebRtcCallService();

  // Default stubs so tests don't crash on common calls
  // Use thenAnswer for Stream getters (thenReturn not allowed for Streams)
  when(() => server.onMessageReceived).thenAnswer((_) => const Stream.empty());
  when(() => server.onParticipantCountChanged).thenAnswer((_) => const Stream.empty());
  when(() => server.participantNames).thenReturn([]);
  when(() => server.clientCount).thenReturn(0);

  when(() => client.onMessageReceived).thenAnswer((_) => const Stream.empty());
  when(() => client.isConnected).thenReturn(true);

  // SharedPreferences with username pre-set
  SharedPreferences.setMockInitialValues({
    'lanline_username': username,
  });
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      webSocketServerProvider.overrideWithValue(server),
      webSocketClientProvider.overrideWithValue(client),
      fileTransferProvider.overrideWithValue(fileTransfer),
      discoveryServiceProvider.overrideWithValue(discovery),
      webRtcCallServiceProvider.overrideWithValue(callService),
    ],
  );

  return (
    container: container,
    server: server,
    client: client,
    fileTransfer: fileTransfer,
    discovery: discovery,
    callService: callService,
  );
}
