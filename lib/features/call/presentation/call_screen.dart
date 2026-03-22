import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/webrtc_call_service.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String callId;
  final String myName;
  final String callType; // 'audio' or 'video'
  final bool isInitiator; // true if starting the call, false if joining
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
  final List<String> _participants = [];
  Timer? _durationTimer;
  int _callDurationSeconds = 0;
  bool _callStarted = false;

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
          } else {
            _participants.remove(name);
          }
        });
      }
    };

    _initCall();
    _acquireProximityLock();
  }

  Future<void> _acquireProximityLock() async {
    if (Platform.isAndroid) {
      try {
        await _proximityChannel.invokeMethod('acquire');
      } catch (_) {}
    }
  }

  Future<void> _releaseProximityLock() async {
    if (Platform.isAndroid) {
      try {
        await _proximityChannel.invokeMethod('release');
      } catch (_) {}
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
      } else {
        await _callService.joinCall(
          callId: widget.callId,
          myName: widget.myName,
          type: widget.callType,
        );
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
      if (mounted) {
        setState(() => _callDurationSeconds++);
      }
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

  void _endCall() {
    _callService.endCall(widget.myName);
  }

  void _popWithDuration() {
    _releaseProximityLock();
    if (mounted) {
      Navigator.pop(context, _callDurationSeconds);
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _releaseProximityLock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Call type icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blueAccent.withValues(alpha: 0.3),
                      Colors.purpleAccent.withValues(alpha: 0.2),
                    ],
                  ),
                ),
                child: Icon(
                  widget.callType == 'video' ? Icons.videocam : Icons.call,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              // Call status
              Text(
                widget.callType == 'video' ? 'Video Call' : 'Audio Call',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              // Duration
              Text(
                _callStarted
                    ? (_participants.isEmpty
                        ? 'Waiting for participants...'
                        : _formatDuration(_callDurationSeconds))
                    : 'Connecting...',
                style: TextStyle(
                  color: _participants.isEmpty ? Colors.orangeAccent : Colors.grey.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              // Participant avatars
              if (_participants.isNotEmpty) ...[
                const Text(
                  'IN CALL',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildParticipantAvatar(widget.myName, isYou: true),
                    ..._participants.map((p) => _buildParticipantAvatar(p)),
                  ],
                ),
              ] else ...[
                _buildParticipantAvatar(widget.myName, isYou: true),
              ],
              const Spacer(flex: 3),
              // Call controls
              Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: _isMuted ? 'Unmute' : 'Mute',
                      active: _isMuted,
                      activeColor: Colors.redAccent,
                      onTap: _toggleMute,
                    ),
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      label: 'Speaker',
                      active: _isSpeakerOn,
                      activeColor: Colors.blueAccent,
                      onTap: _toggleSpeaker,
                    ),
                    _buildEndCallButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantAvatar(String name, {bool isYou = false}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isYou
                ? Colors.blueAccent.withValues(alpha: 0.2)
                : Colors.purpleAccent.withValues(alpha: 0.2),
            border: Border.all(
              color: isYou ? Colors.blueAccent : Colors.purpleAccent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                color: isYou ? Colors.blueAccent : Colors.purpleAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isYou ? 'You' : name,
          style: TextStyle(
            color: isYou ? Colors.grey : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? activeColor.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: active ? activeColor : Colors.grey.shade700,
                width: 2,
              ),
            ),
            child: Icon(icon, color: active ? activeColor : Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: active ? activeColor : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
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
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.redAccent,
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          const Text(
            'End',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
