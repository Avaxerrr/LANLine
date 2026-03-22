# LANLine

A LAN-based chat, file sharing, and calling app built with Flutter. No internet required — devices communicate directly over local WiFi.

## Features

- **Real-time messaging** — instant text chat over WebSocket
- **Audio & video calls** — peer-to-peer via WebRTC, no external servers
- **File sharing** — send and receive files of any type with chunked transfers
- **End-to-end encryption** — messages encrypted before transmission
- **Cross-platform** — runs on Android and Windows
- **Zero setup** — no accounts, no cloud, no sign-up. Just connect to the same WiFi

## How it works

One device hosts a room (WebSocket server), others join by scanning a QR code or entering the room details. All communication stays on your local network.

- **Messaging & signaling** — WebSocket server/client architecture
- **Calls** — WebRTC audio/video with signaling over the existing WebSocket connection. No STUN/TURN servers needed on LAN
- **File transfers** — chunked binary transfer over WebSocket with progress tracking

## Build

```sh
flutter pub get
flutter run                    # debug on connected device
flutter build apk --release    # Android APK
flutter build windows          # Windows desktop
```

## Requirements

- Flutter SDK ^3.11.3
- Android 5.0+ (API 21) or Windows 10+
- Devices must be on the same local network

## Permissions (Android)

- Camera & Microphone — for audio/video calls
- WiFi state — for LAN discovery
- Storage — for file sharing/downloads
- Notifications — for incoming call/message alerts

## Tech Stack

- **Flutter** — cross-platform UI
- **flutter_riverpod** — state management
- **flutter_webrtc** — audio/video calling
- **WebSocket** — real-time messaging and signaling
- **Platform channels** — Android-native ringtone, vibration, proximity sensor

## License

This project is not yet licensed.
