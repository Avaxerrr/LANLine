import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanline/core/db/app_database.dart';
import 'package:lanline/core/repositories/peers_repository.dart';
import 'package:lanline/core/repositories/requests_repository.dart';

void main() {
  late AppDatabase database;
  late PeersRepository peersRepository;
  late RequestsRepository requestsRepository;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    peersRepository = PeersRepository(database);
    requestsRepository = RequestsRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedPeer({
    required String peerId,
    String displayName = 'Peer',
    String relationshipState = 'discovered',
  }) {
    return peersRepository.upsertPeer(
      peerId: peerId,
      displayName: displayName,
      relationshipState: relationshipState,
    );
  }

  test('sendConnectionRequest creates a pending outgoing request', () async {
    await seedPeer(peerId: 'peer-bob', displayName: 'Bob');

    final request = await requestsRepository.sendConnectionRequest(
      peerId: 'peer-bob',
      message: 'let us connect',
    );

    final peer = await peersRepository.getPeerByPeerId('peer-bob');
    final pendingOutgoing = await requestsRepository
        .watchPendingOutgoingRequests()
        .first;

    expect(request.peerId, 'peer-bob');
    expect(request.direction, 'outgoing');
    expect(request.status, 'pending');
    expect(request.message, 'let us connect');
    expect(peer?.relationshipState, 'pending_outgoing');
    expect(pendingOutgoing, hasLength(1));
    expect(pendingOutgoing.single.id, request.id);
  });

  test(
    'acceptRequest marks the request accepted and the peer accepted',
    () async {
      await seedPeer(peerId: 'peer-amy', displayName: 'Amy');
      final request = await requestsRepository.createRequest(
        peerId: 'peer-amy',
        direction: 'incoming',
        message: 'hi from amy',
      );

      final updated = await requestsRepository.acceptRequest(request.id);
      final peer = await peersRepository.getPeerByPeerId('peer-amy');
      final pendingIncoming = await requestsRepository
          .watchPendingIncomingRequests()
          .first;

      expect(updated.status, 'accepted');
      expect(updated.respondedAt, isNotNull);
      expect(peer?.relationshipState, 'accepted');
      expect(pendingIncoming, isEmpty);
    },
  );

  test(
    'declineRequest marks the request declined and resets the peer state',
    () async {
      await seedPeer(peerId: 'peer-zoe', displayName: 'Zoe');
      final request = await requestsRepository.createRequest(
        peerId: 'peer-zoe',
        direction: 'incoming',
        message: 'hello there',
      );

      final updated = await requestsRepository.declineRequest(request.id);
      final peer = await peersRepository.getPeerByPeerId('peer-zoe');
      final pendingIncoming = await requestsRepository
          .watchPendingIncomingRequests()
          .first;

      expect(updated.status, 'declined');
      expect(updated.respondedAt, isNotNull);
      expect(peer?.relationshipState, 'discovered');
      expect(pendingIncoming, isEmpty);
    },
  );

  test(
    'cancelRequest marks the request cancelled and resets the peer state',
    () async {
      await seedPeer(peerId: 'peer-max', displayName: 'Max');
      final request = await requestsRepository.sendConnectionRequest(
        peerId: 'peer-max',
      );

      final updated = await requestsRepository.cancelRequest(request.id);
      final peer = await peersRepository.getPeerByPeerId('peer-max');
      final pendingOutgoing = await requestsRepository
          .watchPendingOutgoingRequests()
          .first;

      expect(updated.status, 'cancelled');
      expect(updated.respondedAt, isNotNull);
      expect(peer?.relationshipState, 'discovered');
      expect(pendingOutgoing, isEmpty);
    },
  );

  test('blockPeer marks the peer and request as blocked', () async {
    await seedPeer(peerId: 'peer-eve', displayName: 'Eve');
    final request = await requestsRepository.sendConnectionRequest(
      peerId: 'peer-eve',
    );

    await requestsRepository.blockPeer(
      peerId: 'peer-eve',
      requestId: request.id,
    );

    final peer = await peersRepository.getPeerByPeerId('peer-eve');
    final updatedRequest = await (database.select(
      database.contactRequestsTable,
    )..where((tbl) => tbl.id.equals(request.id))).getSingle();

    expect(peer?.relationshipState, 'blocked');
    expect(peer?.isBlocked, isTrue);
    expect(updatedRequest.status, 'blocked');
    expect(updatedRequest.respondedAt, isNotNull);
  });
}
