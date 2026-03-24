import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/network/v2_request_signaling_service.dart';
import 'package:lanline/core/providers/username_provider.dart';
import 'package:lanline/core/providers/v2_database_provider.dart';
import 'package:lanline/core/providers/v2_identity_provider.dart';
import 'package:lanline/core/providers/v2_group_protocol_provider.dart';
import 'package:lanline/core/providers/v2_repository_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockV2PeerSignalingService extends Mock
    implements V2RequestSignalingService {}

void main() {
  group('V2GroupProtocolController', () {
    late AppDatabase database;
    late MockV2PeerSignalingService signalingService;
    late StreamController<String> incomingMessages;
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      database = AppDatabase(executor: NativeDatabase.memory());
      signalingService = MockV2PeerSignalingService();
      incomingMessages = StreamController<String>.broadcast();

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
          v2RequestSignalingServiceProvider.overrideWithValue(signalingService),
        ],
      );

      addTearDown(container.dispose);
    });

    tearDown(() async {
      await incomingMessages.close();
      await database.close();
    });

    test(
      'createGroupConversation stores group members and sends invites',
      () async {
        final peersRepository = container.read(peersRepositoryProvider);
        final conversationsRepository = container.read(
          conversationsRepositoryProvider,
        );
        final messagesRepository = container.read(messagesRepositoryProvider);
        final localIdentity = await container
            .read(identityServiceProvider)
            .bootstrap();

        await peersRepository.upsertPeer(
          peerId: 'peer-a',
          displayName: 'Alice',
          relationshipState: 'accepted',
        );
        await peersRepository.upsertPeer(
          peerId: 'peer-b',
          displayName: 'Bob',
          relationshipState: 'accepted',
        );
        await peersRepository.upsertPresence(
          peerId: 'peer-a',
          status: 'online',
          isReachable: true,
          transportType: 'lan',
          host: '192.168.1.21',
          port: V2RequestSignalingService.defaultPort,
        );
        await peersRepository.upsertPresence(
          peerId: 'peer-b',
          status: 'online',
          isReachable: true,
          transportType: 'lan',
          host: '192.168.1.22',
          port: V2RequestSignalingService.defaultPort,
        );

        final conversation = await container
            .read(v2GroupProtocolControllerProvider)
            .createGroupConversation(
              title: 'LAN Crew',
              invitedPeerIds: const ['peer-a', 'peer-b'],
            );

        final members = await conversationsRepository.getConversationMembers(
          conversation.id,
        );
        final messages = await messagesRepository
            .watchMessages(conversation.id)
            .first;

        expect(conversation.type, 'group');
        expect(members, hasLength(3));
        expect(
          members
              .where((member) => member.role == 'admin')
              .map((m) => m.peerId),
          contains(localIdentity.peerId),
        );
        expect(
          members
              .where((member) => member.role == 'invited')
              .map((m) => m.peerId),
          containsAll(['peer-a', 'peer-b']),
        );
        expect(messages.single.type, 'system');
        expect(messages.single.textBody, contains('created the group'));

        verify(
          () => signalingService.sendMessage(
            host: '192.168.1.21',
            port: V2RequestSignalingService.defaultPort,
            payload: any(named: 'payload'),
          ),
        ).called(1);
        verify(
          () => signalingService.sendMessage(
            host: '192.168.1.22',
            port: V2RequestSignalingService.defaultPort,
            payload: any(named: 'payload'),
          ),
        ).called(1);
      },
    );

    test(
      'incoming invite creates a pending group conversation for the local user',
      () async {
        await container.read(v2GroupProtocolControllerProvider).start();
        final peersRepository = container.read(peersRepositoryProvider);
        final conversationsRepository = container.read(
          conversationsRepositoryProvider,
        );
        final localIdentity = await container
            .read(identityServiceProvider)
            .bootstrap();

        await peersRepository.upsertPeer(
          peerId: 'peer-admin',
          displayName: 'Admin',
          relationshipState: 'accepted',
        );

        incomingMessages.add(
          jsonEncode({
            'protocol': 'lanline_v2_group',
            'action': 'group_invite',
            'conversationId': 'group-1',
            'title': 'LAN Crew',
            'senderPeerId': 'peer-admin',
            'senderDisplayName': 'Admin',
            'members': [
              {'peerId': 'peer-admin', 'displayName': 'Admin', 'role': 'admin'},
              {
                'peerId': localIdentity.peerId,
                'displayName': 'Local User',
                'role': 'invited',
              },
              {
                'peerId': 'peer-other',
                'displayName': 'Other User',
                'role': 'invited',
              },
            ],
          }),
        );

        await Future<void>.delayed(const Duration(milliseconds: 20));

        final conversation = await conversationsRepository.getConversationById(
          'group-1',
        );
        final localMembership = await conversationsRepository.getMembership(
          conversationId: 'group-1',
          peerId: localIdentity.peerId,
        );

        expect(conversation, isNotNull);
        expect(conversation!.type, 'group');
        expect(conversation.title, 'LAN Crew');
        expect(localMembership, isNotNull);
        expect(localMembership!.role, 'invited');
      },
    );

    test(
      'sendGroupTextMessage sends to joined reachable members only',
      () async {
        final peersRepository = container.read(peersRepositoryProvider);
        final conversationsRepository = container.read(
          conversationsRepositoryProvider,
        );
        final messagesRepository = container.read(messagesRepositoryProvider);
        final localIdentity = await container
            .read(identityServiceProvider)
            .bootstrap();

        await peersRepository.upsertPeer(
          peerId: 'peer-a',
          displayName: 'Alice',
          relationshipState: 'accepted',
        );
        await peersRepository.upsertPeer(
          peerId: 'peer-b',
          displayName: 'Bob',
          relationshipState: 'accepted',
        );
        await peersRepository.upsertPresence(
          peerId: 'peer-a',
          status: 'online',
          isReachable: true,
          transportType: 'lan',
          host: '192.168.1.21',
          port: V2RequestSignalingService.defaultPort,
        );

        final conversation = await conversationsRepository
            .createGroupConversation(
              localPeerId: localIdentity.peerId,
              title: 'LAN Crew',
              invitedPeerIds: const ['peer-a', 'peer-b'],
            );
        await conversationsRepository.updateMemberRole(
          conversationId: conversation.id,
          peerId: 'peer-a',
          role: 'member',
        );

        final sent = await container
            .read(v2GroupProtocolControllerProvider)
            .sendGroupTextMessage(
              conversationId: conversation.id,
              text: 'Hello group',
            );

        final messages = await messagesRepository
            .watchMessages(conversation.id)
            .first;

        expect(sent.status, 'sent');
        expect(messages.last.textBody, 'Hello group');
        verify(
          () => signalingService.sendMessage(
            host: '192.168.1.21',
            port: V2RequestSignalingService.defaultPort,
            payload: any(named: 'payload'),
          ),
        ).called(1);
        verifyNever(
          () => signalingService.sendMessage(
            host: '192.168.1.22',
            port: any(named: 'port'),
            payload: any(named: 'payload'),
          ),
        );
      },
    );

    test('sendGroupTextMessage preserves reply metadata', () async {
      final peersRepository = container.read(peersRepositoryProvider);
      final conversationsRepository = container.read(
        conversationsRepositoryProvider,
      );
      final messagesRepository = container.read(messagesRepositoryProvider);
      final localIdentity = await container
          .read(identityServiceProvider)
          .bootstrap();

      await peersRepository.upsertPeer(
        peerId: 'peer-a',
        displayName: 'Alice',
        relationshipState: 'accepted',
      );
      await peersRepository.upsertPresence(
        peerId: 'peer-a',
        status: 'online',
        isReachable: true,
        transportType: 'lan',
        host: '192.168.1.21',
        port: V2RequestSignalingService.defaultPort,
      );

      final conversation = await conversationsRepository
          .createGroupConversation(
            localPeerId: localIdentity.peerId,
            title: 'LAN Crew',
            invitedPeerIds: const ['peer-a'],
          );
      await conversationsRepository.updateMemberRole(
        conversationId: conversation.id,
        peerId: 'peer-a',
        role: 'member',
      );
      final original = await messagesRepository.insertMessage(
        conversationId: conversation.id,
        senderPeerId: 'peer-a',
        type: 'text',
        textBody: 'Original group message',
        status: 'delivered',
      );

      final reply = await container
          .read(v2GroupProtocolControllerProvider)
          .sendGroupTextMessage(
            conversationId: conversation.id,
            text: 'Reply group',
            replyToMessageId: original.id,
          );

      expect(reply.replyToMessageId, original.id);
    });

    test('incoming invite from untrusted peer is ignored', () async {
      await container.read(v2GroupProtocolControllerProvider).start();
      final conversationsRepository = container.read(
        conversationsRepositoryProvider,
      );
      final localIdentity = await container
          .read(identityServiceProvider)
          .bootstrap();

      incomingMessages.add(
        jsonEncode({
          'protocol': 'lanline_v2_group',
          'action': 'group_invite',
          'conversationId': 'rogue-group',
          'title': 'Suspicious',
          'senderPeerId': 'unknown-peer',
          'senderDisplayName': 'Intruder',
          'members': [
            {
              'peerId': 'unknown-peer',
              'displayName': 'Intruder',
              'role': 'admin',
            },
            {
              'peerId': localIdentity.peerId,
              'displayName': 'Local User',
              'role': 'invited',
            },
          ],
        }),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      final conversation = await conversationsRepository.getConversationById(
        'rogue-group',
      );
      expect(conversation, isNull);
    });
  });
}
