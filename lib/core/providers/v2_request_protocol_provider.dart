import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../identity/identity_service.dart';
import '../network/protocol_validation.dart';
import '../network/v2_request_signaling_service.dart';
import '../repositories/peers_repository.dart';
import '../repositories/requests_repository.dart';
import '../security/device_signature_service.dart';
import 'security_providers.dart';
import 'v2_identity_provider.dart';
import 'v2_repository_providers.dart';

class V2RequestProtocolController {
  final V2RequestSignalingService _signalingService;
  final IdentityService _identityService;
  final DeviceSignatureService _deviceSignatureService;
  final PeersRepository _peersRepository;
  final RequestsRepository _requestsRepository;
  final Uuid _uuid;

  StreamSubscription<String>? _messageSubscription;
  Future<void>? _startFuture;
  LocalIdentityRow? _localIdentity;

  V2RequestProtocolController({
    required V2RequestSignalingService signalingService,
    required IdentityService identityService,
    required DeviceSignatureService deviceSignatureService,
    required PeersRepository peersRepository,
    required RequestsRepository requestsRepository,
    Uuid? uuid,
  }) : _signalingService = signalingService,
       _identityService = identityService,
       _deviceSignatureService = deviceSignatureService,
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
    if (!isValidOptionalProtocolText(
      message,
      maxLength: kMaxProtocolRequestMessageLength,
    )) {
      throw StateError('Request message is too long.');
    }
    final peer = await _requirePeer(peerId);
    final endpoint = await _resolveEndpoint(peerId);
    final requestId = _uuid.v4();
    final payload = await _buildSignedPayload({
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
      host: endpoint.host,
      port: endpoint.port,
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
    final endpoint = await _resolveEndpoint(request.peerId);
    final payload = await _buildSignedPayload({
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
      host: endpoint.host,
      port: endpoint.port,
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
      _localIdentity ??= await _identityService.bootstrap();
      final data = jsonDecode(rawMessage);
      if (data is! Map<String, dynamic> ||
          data['protocol'] != 'lanline_v2_request') {
        return;
      }

      final rawSenderPeerId = data['senderPeerId']?.toString();
      final rawRequestId = data['requestId']?.toString();
      final action = data['action']?.toString();
      final senderSigningPublicKey = data['senderSigningPublicKey']?.toString();
      final signature = data['signature']?.toString();
      if (!isValidProtocolIdentifier(rawSenderPeerId) ||
          !isValidProtocolIdentifier(rawRequestId) ||
          !isValidOptionalProtocolText(
            senderSigningPublicKey,
            maxLength: kMaxProtocolSigningPublicKeyLength,
          ) ||
          !isValidOptionalProtocolText(
            signature,
            maxLength: kMaxProtocolSignatureLength,
          ) ||
          action == null ||
          (_localIdentity != null &&
              rawSenderPeerId == _localIdentity!.peerId)) {
        return;
      }
      final senderPeerId = rawSenderPeerId!.trim();
      final requestId = rawRequestId!.trim();

      if (action == 'request' &&
          !isValidOptionalProtocolText(
            data['message']?.toString(),
            maxLength: kMaxProtocolRequestMessageLength,
          )) {
        return;
      }

      final existingPeer = await _peersRepository.getPeerByPeerId(senderPeerId);
      final verified = await _verifySignedPayload(
        data,
        fallbackPublicKey:
            existingPeer?.signingPublicKey ?? senderSigningPublicKey,
      );
      if (!verified) {
        debugPrint(
          '[V2RequestProtocolController] Ignored unsigned or invalid request '
          'payload from $senderPeerId.',
        );
        return;
      }
      if (action == 'request' && (existingPeer?.isBlocked ?? false)) {
        return;
      }
      if (action != 'request') {
        final existingRequest = await _requestsRepository.getRequestById(
          requestId,
        );
        if (existingRequest == null || existingRequest.peerId != senderPeerId) {
          debugPrint(
            '[V2RequestProtocolController] Ignored orphaned request status '
            '"$action" for $requestId from $senderPeerId.',
          );
          return;
        }
      }

      final displayName =
          isValidProtocolDisplayName(data['senderDisplayName']?.toString())
          ? data['senderDisplayName']!.toString().trim()
          : (existingPeer?.displayName ?? senderPeerId);
      final deviceLabel = data['senderDeviceLabel']?.toString();
      final fingerprint = data['senderFingerprint']?.toString();

      await _peersRepository.upsertPeer(
        peerId: senderPeerId,
        displayName: displayName,
        deviceLabel:
            isValidOptionalProtocolText(
              deviceLabel,
              maxLength: kMaxProtocolDeviceLabelLength,
            )
            ? deviceLabel?.trim()
            : existingPeer?.deviceLabel,
        fingerprint:
            isValidOptionalProtocolText(
              fingerprint,
              maxLength: kMaxProtocolFingerprintLength,
            )
            ? fingerprint?.trim()
            : existingPeer?.fingerprint,
        signingPublicKey:
            senderSigningPublicKey?.trim() ?? existingPeer?.signingPublicKey,
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

  Future<({String host, int port})> _resolveEndpoint(String peerId) async {
    final peer = await _peersRepository.getPeerByPeerId(peerId);
    if (peer != null && peer.useTunnel) {
      final host = peer.tunnelHost?.trim();
      if (host == null || host.isEmpty) {
        throw StateError(
          'Tunnel is enabled but no tunnel host is configured.',
        );
      }
      return (
        host: host,
        port: peer.tunnelPort ?? V2RequestSignalingService.defaultPort,
      );
    }

    final presence = await _peersRepository.getPresenceByPeerId(peerId);
    if (presence == null || !presence.isReachable || presence.host == null) {
      throw StateError('Peer is not reachable right now.');
    }
    return (
      host: presence.host!,
      port: presence.port ?? V2RequestSignalingService.defaultPort,
    );
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    _startFuture = null;
    await _signalingService.stopServer();
  }

  Future<String> _buildSignedPayload(Map<String, dynamic> payload) async {
    final signingPublicKey =
        _localIdentity!.signingPublicKey ??
        (await _deviceSignatureService.ensureIdentity()).publicKey;
    final signature = await _deviceSignatureService.signPayload(payload);
    return jsonEncode({
      ...payload,
      'senderSigningPublicKey': signingPublicKey,
      'signature': signature,
    });
  }

  Future<bool> _verifySignedPayload(
    Map<String, dynamic> payload, {
    required String? fallbackPublicKey,
  }) async {
    final signature = payload['signature']?.toString();
    final publicKey =
        payload['senderSigningPublicKey']?.toString() ?? fallbackPublicKey;
    if (signature == null ||
        publicKey == null ||
        !isValidOptionalProtocolText(
          signature,
          maxLength: kMaxProtocolSignatureLength,
        ) ||
        !isValidOptionalProtocolText(
          publicKey,
          maxLength: kMaxProtocolSigningPublicKeyLength,
        )) {
      return false;
    }

    final signedPayload = Map<String, dynamic>.from(payload)
      ..remove('signature')
      ..remove('senderSigningPublicKey');
    return _deviceSignatureService.verifyPayload(
      payload: signedPayload,
      publicKeyBase64: publicKey,
      signatureBase64: signature,
    );
  }
}

final v2RequestProtocolControllerProvider =
    Provider<V2RequestProtocolController>((ref) {
      final controller = V2RequestProtocolController(
        signalingService: ref.read(v2RequestSignalingServiceProvider),
        identityService: ref.read(identityServiceProvider),
        deviceSignatureService: ref.read(deviceSignatureServiceProvider),
        peersRepository: ref.read(peersRepositoryProvider),
        requestsRepository: ref.read(requestsRepositoryProvider),
      );

      unawaited(controller.start());
      ref.onDispose(controller.dispose);
      return controller;
    });
