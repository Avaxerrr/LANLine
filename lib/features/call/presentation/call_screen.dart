import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/network/webrtc_call_service.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String myName;
  final String callType;
  final bool isInitiator;
  final void Function(String message) sendSignal;

  const CallScreen({
    super.key,
    required this.callId,
    required this.myName,
    required this.callType,
    required this.isInitiator,
    required this.sendSignal,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  static const _channel = MethodChannel('com.lanline.lanline/proximity');
  static const _callTimeout = Duration(seconds: 30);

  late final WebRtcCallService _callService;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isOnHold = false;
  bool _isFrontCamera = true;
  bool _isVideoEnabled = false;
  final List<String> _participants = [];
  Timer? _durationTimer;
  Timer? _timeoutTimer;
  Timer? _statsTimer;
  int _callDurationSeconds = 0;
  bool _callStarted = false;
  bool _isConnected = false;
  String _networkQuality = '';

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, Completer<void>> _rendererReady = {};

  @override
  void initState() {
    super.initState();
    _isVideoEnabled = widget.callType == 'video';
    _callService = ref.read(webRtcCallServiceProvider);
    _callService.sendSignal = widget.sendSignal;

    _callService.onCallStateChanged = (state) {
      if (mounted) {
        setState(() {});
        if (state == CallState.idle) {
          _playDisconnectTone();
          _popWithDuration();
        }
      }
    };

    _callService.onParticipantChanged = (name, joined) {
      if (mounted) {
        setState(() {
          if (joined) {
            if (!_participants.contains(name)) _participants.add(name);
            if (!_isConnected) {
              _isConnected = true;
              _stopRingback();
              _cancelTimeout();
              _playConnectTone();
              _startDurationTimer();
              _startStatsMonitor();
            }
          } else {
            _participants.remove(name);
            _remoteRenderers[name]?.dispose();
            _remoteRenderers.remove(name);
          }
        });
      }
    };

    // Remote stream callback — always set up renderers since both
    // audio+video tracks are always present in the stream
    _callService.onRemoteStream = (stream, participantId) {
      if (!mounted) return;
      if (!_remoteRenderers.containsKey(participantId)) {
        final renderer = RTCVideoRenderer();
        final completer = Completer<void>();
        _remoteRenderers[participantId] = renderer;
        _rendererReady[participantId] = completer;
        renderer.initialize().then((_) {
          completer.complete();
          if (mounted) {
            renderer.srcObject = stream;
            setState(() {});
          }
        });
      } else {
        // Wait for initialization before setting srcObject
        final ready = _rendererReady[participantId];
        if (ready != null && !ready.isCompleted) {
          ready.future.then((_) {
            if (mounted) {
              _remoteRenderers[participantId]?.srcObject = stream;
              setState(() {});
            }
          });
        } else {
          _remoteRenderers[participantId]!.srcObject = stream;
          if (mounted) setState(() {});
        }
      }
    };

    _startCallSequence();
  }

  /// Initialize renderer first, then start the call
  Future<void> _startCallSequence() async {
    await _localRenderer.initialize();
    _acquireProximityLock();
    await _initCall();
  }

  // ─── Platform helpers ────────────────────────────────────────

  Future<void> _acquireProximityLock() async {
    if (Platform.isAndroid && !_isVideoEnabled) {
      try { await _channel.invokeMethod('acquire'); } catch (_) {}
    }
  }

  Future<void> _releaseProximityLock() async {
    if (Platform.isAndroid) {
      try { await _channel.invokeMethod('release'); } catch (_) {}
    }
  }

  Future<void> _startRingback() async {
    if (Platform.isAndroid) {
      try { await _channel.invokeMethod('startRingback'); } catch (_) {}
    }
  }

  Future<void> _stopRingback() async {
    if (Platform.isAndroid) {
      try { await _channel.invokeMethod('stopRingback'); } catch (_) {}
    }
  }

  Future<void> _playConnectTone() async {
    if (Platform.isAndroid) {
      try { await _channel.invokeMethod('playConnectTone'); } catch (_) {}
    }
  }

  Future<void> _playDisconnectTone() async {
    if (Platform.isAndroid) {
      try { await _channel.invokeMethod('playDisconnectTone'); } catch (_) {}
    }
  }

  // ─── Call lifecycle ──────────────────────────────────────────

  Future<void> _initCall() async {
    try {
      if (widget.isInitiator) {
        await _callService.startCall(
          callId: widget.callId,
          myName: widget.myName,
          type: widget.callType,
        );
        _startRingback();
        _timeoutTimer = Timer(_callTimeout, () {
          if (!_isConnected && mounted) {
            _stopRingback();
            _callService.endCall(widget.myName);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No answer')),
            );
          }
        });
      } else {
        await _callService.joinCall(
          callId: widget.callId,
          myName: widget.myName,
          type: widget.callType,
        );
        _isConnected = true;
        _playConnectTone();
        _startDurationTimer();
        _startStatsMonitor();
      }

      // Always assign local stream to renderer (tracks are always there)
      if (_callService.localStream != null) {
        _localRenderer.srcObject = _callService.localStream;
      }

      setState(() => _callStarted = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
        _popWithDuration();
      }
    }
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  void _startStatsMonitor() {
    _statsTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _callService.state != CallState.inCall) return;
      final pcs = _callService.peerConnections;
      if (pcs.isEmpty) return;
      try {
        final stats = await pcs.values.first.getStats();
        double? rtt;
        int? packetsLost;
        int? packetsSent;
        for (var report in stats) {
          if (report.type == 'candidate-pair' && report.values['state'] == 'succeeded') {
            rtt = (report.values['currentRoundTripTime'] as num?)?.toDouble();
          }
          if (report.type == 'outbound-rtp' && report.values['kind'] == 'audio') {
            packetsSent = report.values['packetsSent'] as int?;
          }
          if (report.type == 'remote-inbound-rtp' && report.values['kind'] == 'audio') {
            packetsLost = report.values['packetsLost'] as int?;
          }
        }
        String quality = 'excellent';
        if (rtt != null) {
          if (rtt > 0.3) quality = 'poor';
          else if (rtt > 0.15) quality = 'fair';
          else if (rtt > 0.05) quality = 'good';
        }
        if (packetsLost != null && packetsSent != null && packetsSent > 0) {
          final lossRate = packetsLost / packetsSent;
          if (lossRate > 0.1) quality = 'poor';
          else if (lossRate > 0.05 && quality != 'poor') quality = 'fair';
        }
        if (mounted && quality != _networkQuality) {
          setState(() => _networkQuality = quality);
        }
      } catch (_) {}
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ─── Controls ────────────────────────────────────────────────

  void _toggleMute() {
    _callService.toggleMute();
    setState(() => _isMuted = _callService.isMuted);
  }

  void _toggleSpeaker() {
    _callService.toggleSpeaker();
    setState(() => _isSpeakerOn = _callService.isSpeakerOn);
  }

  void _toggleHold() {
    setState(() => _isOnHold = !_isOnHold);
    final stream = _callService.localStream;
    if (stream != null) {
      for (var track in stream.getTracks()) {
        track.enabled = !_isOnHold;
      }
    }
    _callService.sendSignal?.call(jsonEncode({
      'type': 'call_hold',
      'callId': widget.callId,
      'sender': widget.myName,
      'onHold': _isOnHold,
    }));
  }

  void _flipCamera() {
    if (_callService.localStream != null) {
      final videoTracks = _callService.localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        Helper.switchCamera(videoTracks[0]);
        setState(() => _isFrontCamera = !_isFrontCamera);
      }
    }
  }

  /// Simple toggle: just flip track.enabled. Synchronous, no renegotiation.
  void _toggleVideo() {
    final nowEnabled = _callService.toggleVideo();
    setState(() => _isVideoEnabled = nowEnabled);

    // Notify peers about the video state change
    _callService.sendSignal?.call(jsonEncode({
      'type': 'call_video_toggle',
      'callId': widget.callId,
      'sender': widget.myName,
      'videoEnabled': nowEnabled,
    }));

    // Toggle proximity lock: on for audio, off for video
    if (Platform.isAndroid) {
      if (nowEnabled) {
        _releaseProximityLock();
      } else {
        _acquireProximityLock();
      }
    }
  }

  void _endCall() {
    _stopRingback();
    _cancelTimeout();
    _playDisconnectTone();
    _callService.endCall(widget.myName);
  }

  void _popWithDuration() {
    _stopRingback();
    _cancelTimeout();
    _releaseProximityLock();
    if (mounted) Navigator.pop(context, _isConnected ? _callDurationSeconds : 0);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _timeoutTimer?.cancel();
    _statsTimer?.cancel();
    _stopRingback();
    _releaseProximityLock();
    _localRenderer.dispose();
    for (var r in _remoteRenderers.values) { r.dispose(); }
    super.dispose();
  }

  // ─── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: _isVideoEnabled ? _buildVideoLayout() : _buildAudioLayout(),
      ),
    );
  }

  // ─── Network quality badge ───────────────────────────────────

  Widget _buildNetworkBadge() {
    if (_networkQuality.isEmpty || !_isConnected) return const SizedBox.shrink();
    IconData icon;
    Color color;
    switch (_networkQuality) {
      case 'excellent':
        icon = Icons.signal_cellular_4_bar; color = Colors.greenAccent; break;
      case 'good':
        icon = Icons.signal_cellular_alt; color = Colors.lightGreen; break;
      case 'fair':
        icon = Icons.signal_cellular_alt_2_bar; color = Colors.orangeAccent; break;
      case 'poor':
        icon = Icons.signal_cellular_alt_1_bar; color = Colors.redAccent; break;
      default:
        icon = Icons.signal_cellular_4_bar; color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(_networkQuality[0].toUpperCase() + _networkQuality.substring(1),
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─── Hold overlay ────────────────────────────────────────────

  Widget _buildHoldOverlay() {
    if (!_isOnHold) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pause_circle_outline, color: Colors.orangeAccent, size: 64),
              SizedBox(height: 12),
              Text('On Hold', style: TextStyle(color: Colors.orangeAccent, fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Audio Call Layout ───────────────────────────────────────

  Widget _buildAudioLayout() {
    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Colors.blueAccent.withValues(alpha: 0.3), Colors.purpleAccent.withValues(alpha: 0.2)],
                  ),
                ),
                child: const Icon(Icons.call, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text('Audio Call', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                _callStarted
                    ? (_isConnected ? _formatDuration(_callDurationSeconds) : 'Ringing...')
                    : 'Connecting...',
                style: TextStyle(
                  color: _isConnected ? Colors.grey.shade400 : Colors.orangeAccent,
                  fontSize: 16, fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildNetworkBadge(),
              const SizedBox(height: 32),
              _buildParticipantList(),
              const Spacer(flex: 3),
              _buildAudioControls(),
            ],
          ),
        ),
        _buildHoldOverlay(),
      ],
    );
  }

  // ─── Video Call Layout ───────────────────────────────────────

  Widget _buildVideoLayout() {
    final hasRemote = _remoteRenderers.isNotEmpty &&
        _remoteRenderers.values.first.srcObject != null;

    return Stack(
      children: [
        // Remote video fullscreen or waiting placeholder
        if (hasRemote)
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderers.values.first,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          )
        else
          Positioned.fill(
            child: Container(
              color: const Color(0xFF1A1A2E),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Colors.blueAccent.withValues(alpha: 0.4), Colors.purpleAccent.withValues(alpha: 0.3)],
                        ),
                      ),
                      child: const Icon(Icons.videocam, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text('Video Call', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      _callStarted ? (_isConnected ? _formatDuration(_callDurationSeconds) : 'Ringing...') : 'Connecting...',
                      style: TextStyle(color: _isConnected ? Colors.grey.shade400 : Colors.orangeAccent, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    _buildNetworkBadge(),
                  ],
                ),
              ),
            ),
          ),

        // Local camera PIP (top-right)
        if (_callService.isVideoEnabled && _localRenderer.srcObject != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: GestureDetector(
              onTap: _flipCamera,
              child: Container(
                width: 120, height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 2),
                ),
                clipBehavior: Clip.hardEdge,
                child: RTCVideoView(
                  _localRenderer,
                  mirror: _isFrontCamera,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

        // Duration + network (top-left)
        if (_isConnected)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                  child: Text(_formatDuration(_callDurationSeconds), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                _buildNetworkBadge(),
              ],
            ),
          ),

        // Bottom controls
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 32, top: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(icon: _isMuted ? Icons.mic_off : Icons.mic, label: _isMuted ? 'Unmute' : 'Mute', active: _isMuted, activeColor: Colors.redAccent, onTap: _toggleMute),
                _buildControlButton(icon: Icons.cameraswitch, label: 'Flip', active: false, activeColor: Colors.blueAccent, onTap: _flipCamera),
                _buildControlButton(icon: Icons.call, label: 'Audio', active: false, activeColor: Colors.greenAccent, onTap: _toggleVideo),
                _buildControlButton(icon: _isOnHold ? Icons.play_arrow : Icons.pause, label: _isOnHold ? 'Resume' : 'Hold', active: _isOnHold, activeColor: Colors.orangeAccent, onTap: _toggleHold),
                _buildEndCallButton(),
              ],
            ),
          ),
        ),

        _buildHoldOverlay(),
      ],
    );
  }

  // ─── Shared widgets ──────────────────────────────────────────

  Widget _buildParticipantList() {
    if (_participants.isNotEmpty) {
      return Column(
        children: [
          const Text('IN CALL', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16, runSpacing: 12, alignment: WrapAlignment.center,
            children: [
              _buildParticipantAvatar(widget.myName, isYou: true),
              ..._participants.map((p) => _buildParticipantAvatar(p)),
            ],
          ),
        ],
      );
    }
    return _buildParticipantAvatar(widget.myName, isYou: true);
  }

  Widget _buildAudioControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(icon: _isMuted ? Icons.mic_off : Icons.mic, label: _isMuted ? 'Unmute' : 'Mute', active: _isMuted, activeColor: Colors.redAccent, onTap: _toggleMute),
          _buildControlButton(icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down, label: 'Speaker', active: _isSpeakerOn, activeColor: Colors.blueAccent, onTap: _toggleSpeaker),
          _buildControlButton(icon: Icons.videocam, label: 'Video', active: false, activeColor: Colors.greenAccent, onTap: _toggleVideo),
          _buildControlButton(icon: _isOnHold ? Icons.play_arrow : Icons.pause, label: _isOnHold ? 'Resume' : 'Hold', active: _isOnHold, activeColor: Colors.orangeAccent, onTap: _toggleHold),
          _buildEndCallButton(),
        ],
      ),
    );
  }

  Widget _buildParticipantAvatar(String name, {bool isYou = false}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isYou ? Colors.blueAccent : Colors.purpleAccent).withValues(alpha: 0.2),
            border: Border.all(color: isYou ? Colors.blueAccent : Colors.purpleAccent, width: 2),
          ),
          child: Center(child: Text(initial, style: TextStyle(color: isYou ? Colors.blueAccent : Colors.purpleAccent, fontSize: 24, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 6),
        Text(isYou ? 'You' : name, style: TextStyle(color: isYou ? Colors.grey : Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required bool active, required Color activeColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: active ? activeColor : Colors.grey.shade700, width: 2),
            ),
            child: Icon(icon, color: active ? activeColor : Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: active ? activeColor : Colors.grey, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEndCallButton() {
    return GestureDetector(
      onTap: _endCall,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
            child: const Icon(Icons.call_end, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          const Text('End', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
