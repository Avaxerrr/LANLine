import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../network/discovery_service.dart';
import '../network/v2_request_signaling_service.dart';
import '../repositories/peers_repository.dart';
import 'v2_identity_provider.dart';
import 'v2_repository_providers.dart';

class V2PresenceDiscoveryController {
  final DiscoveryService _discoveryService;
  final PeersRepository _peersRepository;
  final Future<LocalIdentityRow> Function() _loadLocalIdentity;

  StreamSubscription<DiscoveredPeerPresence>? _peerSubscription;
  Future<void>? _startFuture;
  LocalIdentityRow? _localIdentity;

  V2PresenceDiscoveryController({
    required DiscoveryService discoveryService,
    required PeersRepository peersRepository,
    required Future<LocalIdentityRow> Function() loadLocalIdentity,
  }) : _discoveryService = discoveryService,
       _peersRepository = peersRepository,
       _loadLocalIdentity = loadLocalIdentity;

  Future<void> start() {
    if (_startFuture != null) return _startFuture!;
    _startFuture = _start();
    return _startFuture!;
  }

  Future<void> _start() async {
    _localIdentity ??= await _loadLocalIdentity();
    await _discoveryService.startListening();

    _peerSubscription ??= _discoveryService.onPeerPresenceDiscovered.listen(
      _handlePeerPresence,
    );

    await _discoveryService.startPeerBroadcasting(
      peerId: _localIdentity!.peerId,
      displayName: _localIdentity!.displayName,
      deviceLabel: _localIdentity!.deviceLabel,
      fingerprint: _localIdentity!.fingerprint,
      isReachable: true,
      status: 'online',
      port: V2RequestSignalingService.defaultPort,
      bindAddress: await _discoveryService.getLocalIpAddress(),
    );
  }

  Future<void> _handlePeerPresence(DiscoveredPeerPresence event) async {
    if (_localIdentity != null && event.peerId == _localIdentity!.peerId) {
      return;
    }

    final existingPeer = await _peersRepository.getPeerByPeerId(event.peerId);

    await _peersRepository.upsertPeer(
      peerId: event.peerId,
      displayName: event.displayName,
      deviceLabel: event.deviceLabel,
      fingerprint: event.fingerprint,
      relationshipState: existingPeer?.relationshipState ?? 'discovered',
      isBlocked: existingPeer?.isBlocked ?? false,
    );

    await _peersRepository.upsertPresence(
      peerId: event.peerId,
      status: event.status,
      isReachable: event.isReachable,
      transportType: event.transportType,
      host: event.ip,
      port: event.port,
      lastHeartbeatAt: event.lastHeartbeatAt,
    );
  }

  Future<void> dispose() async {
    await _peerSubscription?.cancel();
    _peerSubscription = null;
    _startFuture = null;
    _discoveryService.stopPeerBroadcasting();
  }
}

final v2PresenceDiscoveryControllerProvider =
    Provider<V2PresenceDiscoveryController>((ref) {
      final controller = V2PresenceDiscoveryController(
        discoveryService: ref.read(discoveryServiceProvider),
        peersRepository: ref.read(peersRepositoryProvider),
        loadLocalIdentity: () => ref.read(identityServiceProvider).bootstrap(),
      );

      unawaited(controller.start());
      ref.onDispose(controller.dispose);
      return controller;
    });
