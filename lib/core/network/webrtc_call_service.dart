import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final webRtcCallServiceProvider = Provider<WebRtcCallService>((ref) {
  return WebRtcCallService();
});

/// Signaling message types used over WebSocket
class CallSignal {
  static const callStart = 'call_start';
  static const callJoin = 'call_join';
  static const callLeave = 'call_leave';
  static const callEnd = 'call_end';
  static const callOffer = 'call_offer';
  static const callAnswer = 'call_answer';
  static const iceCandidate = 'ice_candidate';
}

enum CallState {
  idle,
  ringing,
  calling,
  inCall,
}

class WebRtcCallService {
  final Map<String, RTCPeerConnection> _peerConnections = {};
  MediaStream? _localStream;

  CallState state = CallState.idle;
  String? activeCallId;
  String? callType;
  final Set<String> callParticipants = {};

  // Callbacks for UI updates
  void Function(CallState state)? onCallStateChanged;
  void Function(String participant, bool joined)? onParticipantChanged;
  void Function(MediaStream stream, String participantId)? onRemoteStream;
  void Function(String message)? sendSignal;

  final Map<String, dynamic> _rtcConfig = {
    'iceServers': <Map<String, dynamic>>[],
    'sdpSemantics': 'unified-plan',
  };

  /// Start a new call (caller initiates)
  Future<void> startCall({
    required String callId,
    required String myName,
    required String type,
  }) async {
    activeCallId = callId;
    callType = type;
    state = CallState.calling;
    callParticipants.add(myName);

    final constraints = <String, dynamic>{
      'audio': true,
      'video': type == 'video',
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);

    sendSignal?.call(jsonEncode({
      'type': CallSignal.callStart,
      'callId': callId,
      'sender': myName,
      'callType': type,
    }));

    state = CallState.inCall;
    onCallStateChanged?.call(state);
  }

  /// Join an existing call (callee accepts)
  Future<void> joinCall({
    required String callId,
    required String myName,
    required String type,
  }) async {
    activeCallId = callId;
    callType = type;
    callParticipants.add(myName);

    final constraints = <String, dynamic>{
      'audio': true,
      'video': type == 'video',
    };
    _localStream = await navigator.mediaDevices.getUserMedia(constraints);

    sendSignal?.call(jsonEncode({
      'type': CallSignal.callJoin,
      'callId': callId,
      'sender': myName,
    }));

    state = CallState.inCall;
    onCallStateChanged?.call(state);
  }

  /// Create a peer connection to a specific remote participant
  Future<void> setupPeerConnection(String remoteName, String myName, {bool makeOffer = true}) async {
    if (_peerConnections.containsKey(remoteName)) return;

    final pc = await createPeerConnection(_rtcConfig);
    _peerConnections[remoteName] = pc;

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        pc.addTrack(track, _localStream!);
      }
    }

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams[0], remoteName);
      }
    };

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      sendSignal?.call(jsonEncode({
        'type': CallSignal.iceCandidate,
        'callId': activeCallId,
        'sender': myName,
        'target': remoteName,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      }));
    };

    pc.onIceConnectionState = (RTCIceConnectionState iceState) {
      if (iceState == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          iceState == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _removePeer(remoteName);
      }
    };

    if (makeOffer) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      sendSignal?.call(jsonEncode({
        'type': CallSignal.callOffer,
        'callId': activeCallId,
        'sender': myName,
        'target': remoteName,
        'sdp': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      }));
    }
  }

  Future<void> handleOffer(String remoteName, String myName, Map<String, dynamic> sdp) async {
    if (!_peerConnections.containsKey(remoteName)) {
      await setupPeerConnection(remoteName, myName, makeOffer: false);
    }

    final pc = _peerConnections[remoteName]!;
    await pc.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    sendSignal?.call(jsonEncode({
      'type': CallSignal.callAnswer,
      'callId': activeCallId,
      'sender': myName,
      'target': remoteName,
      'sdp': {
        'type': answer.type,
        'sdp': answer.sdp,
      },
    }));
  }

  Future<void> handleAnswer(String remoteName, Map<String, dynamic> sdp) async {
    final pc = _peerConnections[remoteName];
    if (pc != null) {
      await pc.setRemoteDescription(RTCSessionDescription(sdp['sdp'], sdp['type']));
    }
  }

  Future<void> handleIceCandidate(String remoteName, Map<String, dynamic> candidate) async {
    final pc = _peerConnections[remoteName];
    if (pc != null) {
      pc.addCandidate(RTCIceCandidate(
        candidate['candidate'],
        candidate['sdpMid'],
        candidate['sdpMLineIndex'],
      ));
    }
  }

  Future<void> leaveCall(String myName) async {
    sendSignal?.call(jsonEncode({
      'type': CallSignal.callLeave,
      'callId': activeCallId,
      'sender': myName,
    }));
    await _cleanup();
  }

  Future<void> endCall(String myName) async {
    sendSignal?.call(jsonEncode({
      'type': CallSignal.callEnd,
      'callId': activeCallId,
      'sender': myName,
    }));
    await _cleanup();
  }

  void _removePeer(String remoteName) {
    _peerConnections[remoteName]?.close();
    _peerConnections.remove(remoteName);
    callParticipants.remove(remoteName);
    onParticipantChanged?.call(remoteName, false);
  }

  void handleParticipantLeft(String remoteName) {
    _removePeer(remoteName);
    if (_peerConnections.isEmpty && state == CallState.inCall) {
      _cleanup();
    }
  }

  Future<void> _cleanup() async {
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    callParticipants.clear();

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream!.dispose();
      _localStream = null;
    }

    activeCallId = null;
    callType = null;
    state = CallState.idle;
    onCallStateChanged?.call(state);
  }

  // ─── Media controls ────────────────────────────────────────

  bool get isMuted {
    final audioTracks = _localStream?.getAudioTracks();
    if (audioTracks != null && audioTracks.isNotEmpty) {
      return !audioTracks[0].enabled;
    }
    return false;
  }

  void toggleMute() {
    final audioTracks = _localStream?.getAudioTracks();
    if (audioTracks != null && audioTracks.isNotEmpty) {
      audioTracks[0].enabled = !audioTracks[0].enabled;
    }
  }

  bool isSpeakerOn = false;
  void toggleSpeaker() {
    isSpeakerOn = !isSpeakerOn;
    Helper.setSpeakerphoneOn(isSpeakerOn);
  }

  /// Toggle video on/off mid-call.
  /// Returns true if video is now enabled, false if disabled.
  Future<bool> toggleVideo() async {
    if (_localStream == null) return false;

    final videoTracks = _localStream!.getVideoTracks();

    if (videoTracks.isNotEmpty) {
      // Video is currently on — disable it
      for (var track in videoTracks) {
        track.enabled = false;
        _localStream!.removeTrack(track);
        track.stop();
      }
      callType = 'audio';
      return false;
    } else {
      // Video is currently off — enable it
      final newStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': true,
      });
      final videoTrack = newStream.getVideoTracks()[0];
      _localStream!.addTrack(videoTrack);

      // Add video track to all peer connections
      for (var pc in _peerConnections.values) {
        pc.addTrack(videoTrack, _localStream!);
      }

      callType = 'video';
      return true;
    }
  }

  bool get hasVideo {
    final videoTracks = _localStream?.getVideoTracks();
    return videoTracks != null && videoTracks.isNotEmpty && videoTracks[0].enabled;
  }

  bool get isVideoCall => callType == 'video';
  MediaStream? get localStream => _localStream;
  Map<String, RTCPeerConnection> get peerConnections => _peerConnections;

  Future<void> dispose() async {
    await _cleanup();
  }
}
