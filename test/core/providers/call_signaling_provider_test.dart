import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/network/request_signaling_service.dart';
import 'package:lanline/core/providers/username_provider.dart';
import 'package:lanline/core/providers/security_providers.dart';
import 'package:lanline/core/providers/database_provider.dart';
import 'package:lanline/core/providers/call_signaling_provider.dart';
import 'package:lanline/core/security/device_signature_service.dart';
import 'package:lanline/core/security/in_memory_secret_store.dart';
import 'package:lanline/core/security/local_data_protection_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPeerSignalingService extends Mock
    implements RequestSignalingService {}

void main() {
  group('CallSignalingNotifier', () {
    late AppDatabase database;
    late MockPeerSignalingService signalingService;
    late StreamController<String> incomingMessages;
    late SharedPreferences prefs;
    late DeviceSignatureService signatureService;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      signalingService = MockPeerSignalingService();
      incomingMessages = StreamController<String>.broadcast();

      signatureService = DeviceSignatureService(InMemorySecretStore());
      SharedPreferences.setMockInitialValues({
        'lanline_username': 'Local User',
      });
      prefs = await SharedPreferences.getInstance();

      when(
        () => signalingService.onMessageReceived,
      ).thenAnswer((_) => incomingMessages.stream);
      when(
        () => signalingService.startServer(
          port: any(named: 'port'),
          bindAddress: any(named: 'bindAddress'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => signalingService.sendMessage(
          host: any(named: 'host'),
          port: any(named: 'port'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
          requestSignalingServiceProvider.overrideWithValue(signalingService),
          deviceSignatureServiceProvider.overrideWithValue(signatureService),
          localDataProtectionServiceProvider.overrideWithValue(
            const PassthroughLocalDataProtectionService(),
          ),
        ],
      );

      addTearDown(container.dispose);
    });

    tearDown(() async {
      await incomingMessages.close();
      await database.close();
    });

    test('incoming call start updates incoming call state', () async {
      await container.read(callSignalingProvider.notifier).start();

      incomingMessages.add(
        jsonEncode({
          'protocol': 'lanline_v2_media',
          'type': 'call_start',
          'senderPeerId': 'peer-remote',
          'senderDisplayName': 'Remote Device',
          'conversationId': 'conversation-remote',
          'callId': 'call-123',
          'callType': 'audio',
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final state = container.read(callSignalingProvider);
      expect(state.incomingCall, isNotNull);
      expect(state.incomingCall!.peerId, 'peer-remote');
      expect(state.incomingCall!.displayName, 'Remote Device');
      expect(state.incomingCall!.callId, 'call-123');
      expect(state.incomingCall!.callType, 'audio');
    });
  });
}
