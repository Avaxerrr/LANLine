# Video Call Feature Rebuild Tracker

Base: working commit cc8bfb0 (video calls confirmed working)
Branch: fix/video-call-rebuild

## Features to re-add (in order)

| # | Feature | Files | Risk | Status |
|---|---------|-------|------|--------|
| 1 | Connect/disconnect tones | call_screen.dart | Low | Pending |
| 2 | Ringback tone improvements | call_screen.dart | Low | Pending |
| 3 | 30s call timeout | call_screen.dart | Low | Pending |
| 4 | Duration timer only after connect | call_screen.dart | Low | Pending |
| 5 | Network quality badge | call_screen.dart | Low | Pending |
| 6 | Hold with overlay | call_screen.dart | Medium | Pending |
| 7 | Desktop guard for RTCVideoView | call_screen.dart | Medium | Pending |
| 8 | Audio/video toggle mid-call | call_screen.dart, webrtc_call_service.dart | High | Pending |
| 9 | Always-acquire-both-tracks | webrtc_call_service.dart | High | Pending |

## Already applied (not stripped)

- Impeller disabled in AndroidManifest.xml (confirmed fix)
- Proximity wake lock release fix in MainActivity.kt
- playConnectTone/playDisconnectTone native methods in MainActivity.kt
- VIBRATE permission in AndroidManifest.xml
- Side-by-side audio/video call buttons in chat_screen.dart
- Busy state auto-decline in chat_screen.dart
- Call summary broadcast in chat_screen.dart
- package_info_plus dynamic version in main.dart/pubspec.yaml

## How to bisect if broken

```sh
git bisect start
git bisect bad          # current HEAD is broken
git bisect good <hash>  # last known good commit hash
# test each commit git bisect suggests, then:
git bisect good   # if video works
git bisect bad    # if video broken
# repeat until it finds the culprit
```
