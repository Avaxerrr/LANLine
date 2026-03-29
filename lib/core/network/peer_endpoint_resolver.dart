import '../repositories/peers_repository.dart';
import 'request_signaling_service.dart';

/// Resolves the network endpoint (host + port) for reaching a peer,
/// preferring tunnel configuration when enabled.
///
/// Shared by all protocol controllers to avoid duplicating resolution logic.
class PeerEndpointResolver {
  final PeersRepository _peersRepository;

  const PeerEndpointResolver(this._peersRepository);

  Future<({String host, int port})> resolve(String peerId) async {
    final peer = await _peersRepository.getPeerByPeerId(peerId);
    if (peer != null && peer.useTunnel) {
      final host = peer.tunnelHost?.trim();
      if (host == null || host.isEmpty) {
        throw StateError(
          'Tunnel is enabled but no tunnel host is configured.',
        );
      }
      final port = peer.tunnelPort ?? RequestSignalingService.defaultPort;
      return (host: host, port: port);
    }

    final presence = await _peersRepository.getPresenceByPeerId(peerId);
    if (presence == null || !presence.isReachable || presence.host == null) {
      throw StateError('Peer is not reachable right now.');
    }
    return (
      host: presence.host!,
      port: presence.port ?? RequestSignalingService.defaultPort,
    );
  }
}
