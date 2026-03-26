import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../network/discovery_service.dart';
import '../network/v2_request_signaling_service.dart';
import '../repositories/peers_repository.dart';
import 'v2_identity_provider.dart';
import 'v2_repository_providers.dart';

class V2PresenceDiscoveryController {
  final DiscoveryService _discoveryService;
  final V2RequestSignalingService _signalingService;
  final PeersRepository _peersRepository;
  final Future<LocalIdentityRow> Function() _loadLocalIdentity;

  StreamSubscription<DiscoveredPeerPresence>? _peerSubscription;
  Timer? _tunnelProbeTimer;
  Timer? _staleSweepTimer;
  Future<void>? _startFuture;
  LocalIdentityRow? _localIdentity;
  Future<bool> Function(HttpRequest)? _httpHandler;

  static const _tunnelProbeInterval = Duration(seconds: 30);
  static const _tunnelProbeTimeout = Duration(seconds: 5);
  static const _staleSweepInterval = Duration(seconds: 30);
  static const _staleThreshold = Duration(seconds: 60);

  V2PresenceDiscoveryController({
    required DiscoveryService discoveryService,
    required V2RequestSignalingService signalingService,
    required PeersRepository peersRepository,
    required Future<LocalIdentityRow> Function() loadLocalIdentity,
  }) : _discoveryService = discoveryService,
       _signalingService = signalingService,
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

    _tunnelProbeTimer ??= Timer.periodic(_tunnelProbeInterval, (_) {
      unawaited(_probeTunnelPeers());
    });
    unawaited(_probeTunnelPeers());

    _staleSweepTimer ??= Timer.periodic(_staleSweepInterval, (_) {
      unawaited(_sweepStalePresence());
    });

    _httpHandler ??= _handleDiscoverRequest;
    _signalingService.registerHttpHandler(_httpHandler!);
  }

  Future<void> _sweepStalePresence() async {
    try {
      final cutoff =
          DateTime.now().millisecondsSinceEpoch - _staleThreshold.inMilliseconds;
      await _peersRepository.markStalePresenceUnreachable(cutoff);
    } catch (error) {
      debugPrint('[V2PresenceDiscovery] Stale sweep failed: $error');
    }
  }

  Future<bool> _handleDiscoverRequest(HttpRequest request) async {
    if (request.uri.path != '/discover') return false;
    final identity = _localIdentity;
    if (identity == null) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      await request.response.close();
      return true;
    }
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({
        'protocol': 'lanline_v2_discover',
        'peerId': identity.peerId,
        'displayName': identity.displayName,
        'deviceLabel': identity.deviceLabel,
        'fingerprint': identity.fingerprint,
      }));
    await request.response.close();
    return true;
  }

  /// Discover a remote peer by connecting to their IP and fetching identity.
  /// Returns the peer info or null if unreachable.
  Future<({String peerId, String displayName, String? deviceLabel, String? fingerprint})?> discoverPeerByIp({
    required String host,
    int? port,
  }) async {
    final resolvedPort = port ?? V2RequestSignalingService.defaultPort;
    try {
      await start();
      final client = HttpClient();
      client.connectionTimeout = _tunnelProbeTimeout;
      final request = await client.getUrl(
        Uri.parse('http://$host:$resolvedPort/discover'),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) {
        client.close();
        return null;
      }
      final body = await response.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic> ||
          data['protocol'] != 'lanline_v2_discover') {
        return null;
      }
      final peerId = data['peerId']?.toString();
      final displayName = data['displayName']?.toString();
      if (peerId == null || peerId.isEmpty || displayName == null) return null;
      if (_localIdentity != null && peerId == _localIdentity!.peerId) {
        return null;
      }
      return (
        peerId: peerId,
        displayName: displayName,
        deviceLabel: data['deviceLabel']?.toString(),
        fingerprint: data['fingerprint']?.toString(),
      );
    } catch (error) {
      debugPrint('[V2PresenceDiscovery] Discover by IP failed: $error');
      return null;
    }
  }

  Future<void> _probeTunnelPeers() async {
    try {
      final tunnelPeers = await _peersRepository.getTunnelPeers();
      for (final peer in tunnelPeers) {
        final host = peer.tunnelHost?.trim();
        if (host == null || host.isEmpty) continue;
        final port = peer.tunnelPort ?? V2RequestSignalingService.defaultPort;
        final reachable = await _tcpProbe(host, port);
        final now = DateTime.now().millisecondsSinceEpoch;
        await _peersRepository.upsertPresence(
          peerId: peer.peerId,
          status: reachable ? 'online' : 'offline',
          isReachable: reachable,
          transportType: 'tunnel',
          host: host,
          port: port,
          lastHeartbeatAt: reachable ? now : null,
          lastProbeAt: now,
        );
      }
    } catch (error) {
      debugPrint(
        '[V2PresenceDiscovery] Tunnel probe failed: $error',
      );
    }
  }

  Future<bool> _tcpProbe(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: _tunnelProbeTimeout,
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
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
    _staleSweepTimer?.cancel();
    _staleSweepTimer = null;
    _tunnelProbeTimer?.cancel();
    _tunnelProbeTimer = null;
    if (_httpHandler != null) {
      _signalingService.unregisterHttpHandler(_httpHandler!);
      _httpHandler = null;
    }
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
        signalingService: ref.read(v2RequestSignalingServiceProvider),
        peersRepository: ref.read(peersRepositoryProvider),
        loadLocalIdentity: () => ref.read(identityServiceProvider).bootstrap(),
      );

      unawaited(controller.start());
      ref.onDispose(controller.dispose);
      return controller;
    });
