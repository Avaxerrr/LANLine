import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../core/network/webrtc_call_service.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String myName;
  final String callType; // 'audio' or 'video'
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

class _CallScreenState extends ConsumerState<CallScreen> with SingleTickerProviderStateMixin {
  static const _proximityChannel = MethodChannel('com.lanline.lanline/proximity');

  late final WebRtcCallService _callService;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isFrontCamera = true;
  final List<String> _participants = [];
  Timer? _durationTimer;
  int _callDurationSeconds = 0;
  bool _callStarted = false;
  bool _isConnected = false; // true when at least one participant joins

  // Video renderers
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  @override
  void initState() {
    super.initState();
    _callService = ref.read(webRtcCallServiceProvider);
    _callService.sendSignal = widget.sendSignal;

    _callService.onCallStateChanged = (state) {
      if (mounted) {
        setState(() {});
        if (state == CallState.idle) {
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
            }
          } else {
            _participants.remove(name);
            _remoteRenderers[name]?.dispose();
            _remoteRenderers.remove(name);
          }
        });
      }
    };

    _callService.onRemoteStream = (stream, participantId) {
      if (mounted && widget.callType == 'video') {
        setState(() {
          if (!_remoteRenderers.containsKey(participantId)) {
            final renderer = RTCVideoRenderer();
            renderer.initialize().then((_) {
              renderer.srcObject = stream;
              if (mounted) setState(() {});
            });
            _remoteRenderers[participantId] = renderer;
          } else {
            _remoteRenderers[participantId]!.srcObject = stream;
          }
        });
      }
    };

    _initRenderers();
    _initCall();
    _acquireProximityLock();
  }

  Future<void> _initRenderers() async {
    if (widget.callType == 'video') {
      await _localRenderer.initialize();
    }
  }

  Future<void> _acquireProximityLock() async {
    if (Platform.isAndroid && widget.callType == 'audio') {
      try { await _proximityChannel.invokeMethod('acquire'); } catch (_) {}
    }
  }

  Future<void> _releaseProximityLock() async {
    if (Platform.isAndroid) {
      try { await _proximityChannel.invokeMethod('release'); } catch (_) {}
    }
  }

  Future<void> _startRingback() async {
    if (Platform.isAndroid) {
      try { await _proximityChannel.invokeMethod('startRingback'); } catch (_) {}
    }
  }

  Future<void> _stopRingback() async {
    if (Platform.isAndroid) {
      try { await _proximityChannel.invokeMethod('stopRingback'); } catch (_) {}
    }
  }

  Future<void> _initCall() async {
    try {
      if (widget.isInitiator) {
        await _callService.startCall(
          callId: widget.callId,
          myName: widget.myName,
          type: widget.callType,
        );
        // Caller hears ring-back tone while waiting
        _startRingback();
      } else {
        await _callService.joinCall(
          callId: widget.callId,
          myName: widget.myName,
          type: widget.callType,
        );
        _isConnected = true;
      }

      // Assign local stream to renderer for video
      if (widget.callType == 'video' && _callService.localStream != null) {
        _localRenderer.srcObject = _callService.localStream;
      }

      setState(() => _callStarted = true);
      _startDurationTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
        _popWithDuration();
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDurationSeconds++);
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleMute() {
    _callService.toggleMute();
    setState(() => _isMuted = _callService.isMuted);
  }

  void _toggleSpeaker() {
    _callService.toggleSpeaker();
    setState(() => _isSpeakerOn = _callService.isSpeakerOn);
  }

  void _flipCamera() {
    if (widget.callType == 'video' && _callService.localStream != null) {
      final videoTracks = _callService.localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        Helper.switchCamera(videoTracks[0]);
        setState(() => _isFrontCamera = !_isFrontCamera);
      }
    }
  }

  void _endCall() {
    _stopRingback();
    _callService.endCall(widget.myName);
  }

  void _popWithDuration() {
    _stopRingback();
    _releaseProximityLock();
    if (mounted) Navigator.pop(context, _callDurationSeconds);
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _stopRingback();
    _releaseProximityLock();
    _localRenderer.dispose();
    for (var r in _remoteRenderers.values) { r.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: isVideo ? _buildVideoLayout() : _buildAudioLayout(),
      ),
    );
  }

  // ─── Audio Call Layout ───────────────────────────────────────

  Widget _buildAudioLayout() {
    return SafeArea(
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
          const SizedBox(height: 40),
          _buildParticipantList(),
          const Spacer(flex: 3),
          _buildAudioControls(),
        ],
      ),
    );
  }

  // ─── Video Call Layout ───────────────────────────────────────

  Widget _buildVideoLayout() {
    return Stack(
      children: [
        // Remote video (full screen) or waiting state
        if (_remoteRenderers.isNotEmpty)
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderers.values.first,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          )
        else
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0D0D0D),
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
                          colors: [Colors.blueAccent.withValues(alpha: 0.3), Colors.purpleAccent.withValues(alpha: 0.2)],
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
                  ],
                ),
              ),
            ),
          ),

        // Local video (picture-in-picture style, top right)
        if (_callService.localStream != null)
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

        // Duration overlay when connected
        if (_isConnected)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDuration(_callDurationSeconds),
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
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
                _buildEndCallButton(),
              ],
            ),
          ),
        ),
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
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: active ? activeColor : Colors.grey.shade700, width: 2),
            ),
            child: Icon(icon, color: active ? activeColor : Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: active ? activeColor : Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
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
            width: 68, height: 68,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.redAccent),
            child: const Icon(Icons.call_end, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          const Text('End', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
