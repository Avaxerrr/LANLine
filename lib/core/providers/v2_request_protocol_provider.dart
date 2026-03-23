import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../identity/identity_service.dart';
import '../network/v2_request_signaling_service.dart';
import '../repositories/peers_repository.dart';
import '../repositories/requests_repository.dart';
import 'v2_identity_provider.dart';
import 'v2_repository_providers.dart';

class V2RequestProtocolController {
  final V2RequestSignalingService _signalingService;
  final IdentityService _identityService;
  final PeersRepository _peersRepository;
  final RequestsRepository _requestsRepository;
  final Uuid _uuid;

  StreamSubscription<String>? _messageSubscription;
  Future<void>? _startFuture;
  LocalIdentityRow? _localIdentity;

  V2RequestProtocolController({
    required V2RequestSignalingService signalingService,
    required IdentityService identityService,
    required PeersRepository peersRepository,
    required RequestsRepository requestsRepository,
    Uuid? uuid,
  }) : _signalingService = signalingService,
       _identityService = identityService,
       _peersRepository = peersRepository,
       _requestsRepository = requestsRepository,
       _uuid = uuid ?? const Uuid();

  Future<void> start() {
    if (_startFuture != null) return _startFuture!;
    _startFuture = _start();
    return _startFuture!;
  }

  Future<void> _start() async {
    _localIdentity ??= await _identityService.bootstrap();
    await _signalingService.startServer();
    _messageSubscription ??= _signalingService.onMessageReceived.listen(
      _handleIncomingMessage,
    );
  }

  Future<ContactRequestRow> sendConnectionRequest({
    required String peerId,
    String? message,
  }) async {
    await start();
    final peer = await _requirePeer(peerId);
    final presence = await _requireReachablePresence(peerId);
    final requestId = _uuid.v4();
    final payload = jsonEncode({
      'protocol': 'lanline_v2_request',
      'action': 'request',
      'requestId': requestId,
      'senderPeerId': _localIdentity!.peerId,
      'senderDisplayName': _localIdentity!.displayName,
      'senderDeviceLabel': _localIdentity!.deviceLabel,
      'senderFingerprint': _localIdentity!.fingerprint,
      'message': message,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _signalingService.sendMessage(
      host: presence.host!,
      port: presence.port ?? V2RequestSignalingService.defaultPort,
      payload: payload,
    );

    await _peersRepository.upsertPeer(
      peerId: peer.peerId,
      displayName: peer.displayName,
      deviceLabel: peer.deviceLabel,
      fingerprint: peer.fingerprint,
      relationshipState: 'pending_outgoing',
      isBlocked: peer.isBlocked,
    );

    return _requestsRepository.sendConnectionRequest(
      peerId: peerId,
      message: message,
      requestId: requestId,
    );
  }

  Future<ContactRequestRow> acceptRequest(String requestId) async {
    await start();
    final request = await _requestsRepository.acceptRequest(requestId);
    await _trySendStatusUpdate(request: request, action: 'accepted');
    return request;
  }

  Future<ContactRequestRow> declineRequest(String requestId) async {
    await start();
    final request = await _requestsRepository.declineRequest(requestId);
    await _trySendStatusUpdate(request: request, action: 'declined');
    return request;
  }

  Future<ContactRequestRow> cancelRequest(String requestId) async {
    await start();
    final request = await _requestsRepository.cancelRequest(requestId);
    await _trySendStatusUpdate(request: request, action: 'cancelled');
    return request;
  }

  Future<void> blockPeer({required String peerId, String? requestId}) async {
    await start();
    ContactRequestRow? request;
    if (requestId != null) {
      request = await _requestsRepository.getRequestById(requestId);
    }

    await _requestsRepository.blockPeer(peerId: peerId, requestId: requestId);

    if (request != null) {
      await _trySendStatusUpdate(request: request, action: 'blocked');
    }
  }

  Future<void> _sendStatusUpdate({
    required ContactRequestRow request,
    required String action,
  }) async {
    final presence = await _requireReachablePresence(request.peerId);
    final payload = jsonEncode({
      'protocol': 'lanline_v2_request',
      'action': action,
      'requestId': request.id,
      'senderPeerId': _localIdentity!.peerId,
      'senderDisplayName': _localIdentity!.displayName,
      'senderDeviceLabel': _localIdentity!.deviceLabel,
      'senderFingerprint': _localIdentity!.fingerprint,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    await _signalingService.sendMessage(
      host: presence.host!,
      port: presence.port ?? V2RequestSignalingService.defaultPort,
      payload: payload,
    );
  }

  Future<void> _trySendStatusUpdate({
    required ContactRequestRow request,
    required String action,
  }) async {
    try {
      await _sendStatusUpdate(request: request, action: action);
    } catch (error) {
      debugPrint(
        '[V2RequestProtocolController] Local "$action" applied but remote '
        'notification failed: $error',
      );
    }
  }

  Future<void> _handleIncomingMessage(String rawMessage) async {
    try {
      final data = jsonDecode(rawMessage);
      if (data is! Map<String, dynamic> ||
          data['protocol'] != 'lanline_v2_request') {
        return;
      }

      final senderPeerId = data['senderPeerId']?.toString();
      if (senderPeerId == null ||
          (_localIdentity != null && senderPeerId == _localIdentity!.peerId)) {
        return;
      }

      final displayName = data['senderDisplayName']?.toString() ?? senderPeerId;
      final deviceLabel = data['senderDeviceLabel']?.toString();
      final fingerprint = data['senderFingerprint']?.toString();
      final action = data['action']?.toString();
      final requestId = data['requestId']?.toString();
      if (requestId == null || action == null) return;

      final existingPeer = await _peersRepository.getPeerByPeerId(senderPeerId);
      if (action == 'request' && (existingPeer?.isBlocked ?? false)) {
        return;
      }

      await _peersRepository.upsertPeer(
        peerId: senderPeerId,
        displayName: displayName,
        deviceLabel: deviceLabel,
        fingerprint: fingerprint,
        relationshipState: existingPeer?.relationshipState ?? 'discovered',
        isBlocked: existingPeer?.isBlocked ?? false,
      );

      switch (action) {
        case 'request':
          await _requestsRepository.receiveConnectionRequest(
            requestId: requestId,
            peerId: senderPeerId,
            message: data['message']?.toString(),
          );
          break;
        case 'accepted':
        case 'declined':
        case 'cancelled':
        case 'blocked':
          await _requestsRepository.applyRemoteRequestStatus(
            requestId: requestId,
            peerId: senderPeerId,
            status: action,
          );
          break;
      }
    } catch (error) {
      debugPrint(
        '[V2RequestProtocolController] Failed to handle incoming request '
        'message: $error',
      );
    }
  }

  Future<PeerRow> _requirePeer(String peerId) async {
    final peer = await _peersRepository.getPeerByPeerId(peerId);
    if (peer == null) {
      throw StateError('Peer $peerId is unknown.');
    }
    return peer;
  }

  Future<PresenceRow> _requireReachablePresence(String peerId) async {
    final presence = await _peersRepository.getPresenceByPeerId(peerId);
    if (presence == null || !presence.isReachable || presence.host == null) {
      throw StateError('Peer is not reachable right now.');
    }
    return presence;
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _startFuture = null;
    await _signalingService.stopServer();
  }
}

final v2RequestProtocolControllerProvider =
    Provider<V2RequestProtocolController>((ref) {
      final controller = V2RequestProtocolController(
        signalingService: ref.read(v2RequestSignalingServiceProvider),
        identityService: ref.read(identityServiceProvider),
        peersRepository: ref.read(peersRepositoryProvider),
        requestsRepository: ref.read(requestsRepositoryProvider),
      );

      unawaited(controller.start());
      ref.onDispose(controller.dispose);
      return controller;
    });
