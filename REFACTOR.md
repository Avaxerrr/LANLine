# LANLine Architecture Refactor

Branch: `refactor/chat-architecture`
Created: 2026-03-22

## Goal

Extract business logic from `chat_screen.dart` (~1600 lines) into testable, reusable Riverpod notifiers and smaller widgets. Prepare the codebase for the messaging app transformation (SQLite persistence, conversation list, DMs).

## Principles

- Move code, don't rewrite. Minimize behavior changes.
- Each phase must leave the app fully functional.
- Write tests for extracted logic.
- One commit per sub-phase for easy rollback.

---

## Phases

### Phase 0: Test Infrastructure
- [ ] Add `mocktail` to dev_dependencies
- [ ] Create `test/helpers/test_helpers.dart` with mock services and Riverpod container setup

### Phase 1: Extract ChatMessage Model
- [ ] Move `ChatMessage` class from `chat_screen.dart` to `lib/core/models/chat_message.dart`
- [ ] Move `isEmojiOnly()`, `_emojiOnlyRegex`, `isImageFile()`, `_imageExtensions` as public utilities
- [ ] Update imports in `chat_screen.dart`
- [ ] Write tests: `test/core/models/chat_message_test.dart`
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes

### Phase 2: Create ChatNotifier (Message State)

#### Phase 2a: Message list + sending
- [ ] Create `lib/core/providers/chat_provider.dart` with `ChatState` and `ChatNotifier`
- [ ] Move `_messages` list into notifier state
- [ ] Move `_sendMessage()` logic into notifier
- [ ] Move `_syncClipboard()` logic into notifier
- [ ] Widget watches `chatProvider` instead of local `_messages`
- [ ] Write tests: `test/core/providers/chat_provider_test.dart` (send message)
- [ ] `flutter analyze` + `flutter test` pass
- [ ] Manual test: send/receive messages

#### Phase 2b: Message receiving/routing
- [ ] Move `_handleIncomingMessage()` into `ChatNotifier`
- [ ] Handle message types: `message`, `ack`, `typing`, `participant_list`, `room_closed`, `error`, `clipboard`
- [ ] Call/file types delegated via callbacks (moved in later phases)
- [ ] Write tests: receive message, ack, typing, participant list, room closed
- [ ] `flutter analyze` + `flutter test` pass
- [ ] Manual test: full conversation flow

#### Phase 2c: Participant tracking + connection setup
- [ ] Move `_participantCount`, `_participantNames`, `_typingUsers` into `ChatState`
- [ ] Move stream subscription setup (server/client) into notifier
- [ ] Write tests: participant count updates, typing indicator timeout
- [ ] `flutter analyze` + `flutter test` pass
- [ ] Manual test: host room, client joins, verify counts

### Phase 3: Extract UI Sub-widgets

#### Phase 3a: Message bubble
- [ ] Create `lib/features/chat/presentation/widgets/chat_message_bubble.dart`
- [ ] Move `_buildMessageBubble`, `_buildMessageContent`, `_buildFileBubble`
- [ ] Move `_formatTimestamp`, `_showMessageOptions`
- [ ] `flutter analyze` passes

#### Phase 3b: Input bar
- [ ] Create `lib/features/chat/presentation/widgets/chat_input_bar.dart`
- [ ] Move `_buildMessageInput`, attachment menu, recording state
- [ ] `flutter analyze` passes

#### Phase 3c: Room info panel
- [ ] Create `lib/features/chat/presentation/widgets/chat_room_info_panel.dart`
- [ ] Move `_showRoomInfoPanel`, `_infoTile`, `_participantRow`
- [ ] `flutter analyze` passes

#### Phase 3 verification
- [ ] Manual test: visual check, all UI elements render correctly

### Phase 4: Extract FileTransferNotifier
- [ ] Create `lib/core/providers/file_transfer_notifier.dart`
- [ ] Move offer/accept/cancel state machine
- [ ] Move `_pendingFileOffers`, `_downloadProgress`, `_cancelledOffers`, `_acceptedOffers`
- [ ] Move `_sendFile()`, `_acceptFileOffer()`, `_cancelFileOffer()`
- [ ] Move file-related handlers from incoming message router
- [ ] Write tests: `test/core/providers/file_transfer_notifier_test.dart`
- [ ] `flutter analyze` + `flutter test` pass
- [ ] Manual test: send small file, send large file (offer), cancel file

### Phase 5: Extract CallNotifier
- [ ] Create `lib/core/providers/call_provider.dart`
- [ ] Move call signal routing (`_handleIncomingCall`, `_handleCallJoin`, etc.)
- [ ] Move `_sendCallSignal`
- [ ] Move call-related handlers from incoming message router
- [ ] Widget reacts to call state (show dialog, open call screen)
- [ ] Write tests: `test/core/providers/call_provider_test.dart`
- [ ] `flutter analyze` + `flutter test` pass
- [ ] Manual test: audio call, video call, decline call

---

## Post-Refactor: chat_screen.dart Target

~250-300 lines. Responsibilities:
- Watch providers for state
- Render message list (using extracted bubble widget)
- Render input bar (using extracted widget)
- Show app bar with call buttons
- Show incoming call dialog when call provider signals
- Drag-and-drop overlay

---

## Progress Log

### Phase 0+1 - 2026-03-22
Status: Complete (commit 88d1b68)
- Added mocktail, created test helpers with async container builder
- Extracted ChatMessage model + isEmojiOnly + isImageFile to core/models/chat_message.dart
- 16 unit tests for model/helpers
- Gotcha: mocktail requires `thenAnswer` (not `thenReturn`) for Stream getters

### Phase 2a - 2026-03-22
Status: Complete (commit a79c488, fix commit 6c7a175)
- Created ChatNotifier with ChatState in core/providers/chat_provider.dart
- Moved sendMessage, sendClipboard, sendTypingStatus to notifier
- Replaced ALL broadcast/send patterns in chat_screen.dart with chatProvider.notifier.broadcast()
- Bridge pattern: widget still keeps local _messages list for display; notifier also maintains its own list. Will unify in Phase 2b.
- Added 25 unit tests for ChatNotifier
- Gotcha: SharedPreferences must be overridden in the ProviderContainer (not just setMockInitialValues) for usernameProvider to resolve
- Gotcha: chatProvider.notifier.init() in initState crashes Android (red screen) — must wrap in Future.microtask() to defer state modification after build. Windows was silently ignoring this.
- Total tests: 42, all passing
- Manually verified on both Android and Windows — working

### NEXT: Phase 2b
What to do:
- Move `_handleIncomingMessage()` from chat_screen.dart into ChatNotifier
- Handle types: message, ack, typing, participant_list, room_closed, error, clipboard
- Call/file types stay delegated to widget via a callback/stream mechanism
- CRITICAL: Unify message list — remove local `_messages` field from widget, have widget read from `ref.watch(chatProvider).messages` instead
- The `_handleIncomingMessage` method is at ~line 154 in chat_screen.dart, ~250 lines long, giant if/else on `data['type']`
- Widget currently has stream subscription in initState (lines 99-107) that calls `_handleIncomingMessage` — this needs to route to notifier
- For call/file types that need UI interaction (showing dialogs, file I/O), use callbacks registered on the notifier
- Write tests for: receive message, ack, typing timeout, participant list update, room closed, clipboard receive, invalid JSON fallback

---

## Architecture After Refactor

```
lib/
  core/
    models/
      room_model.dart          (unchanged)
      chat_message.dart        (NEW - extracted from chat_screen)
    network/
      discovery_service.dart   (unchanged)
      encryption_manager.dart  (unchanged)
      file_transfer_manager.dart (unchanged - handles chunking)
      webrtc_call_service.dart (unchanged)
      websocket_client.dart    (unchanged)
      websocket_server.dart    (unchanged)
    providers/
      chat_provider.dart       (NEW - ChatNotifier, message state + logic)
      call_provider.dart       (NEW - call routing + state)
      file_transfer_notifier.dart (NEW - offer/accept/cancel state machine)
      room_provider.dart       (unchanged)
      username_provider.dart   (unchanged)
      download_history_provider.dart (unchanged)
    services/
      media_store_service.dart (unchanged)
      notification_service.dart (unchanged)
    theme/
      app_theme.dart           (unchanged)
  features/
    call/presentation/
      call_screen.dart         (unchanged)
    chat/presentation/
      chat_screen.dart         (REFACTORED - ~250 lines, thin widget)
      widgets/
        chat_message_bubble.dart  (NEW - extracted UI)
        chat_input_bar.dart       (NEW - extracted UI)
        chat_room_info_panel.dart (NEW - extracted UI)
    connection/presentation/
      client_scanner_screen.dart (unchanged)
    downloads/presentation/
      download_history_screen.dart (unchanged)
    room/presentation/
      room_list_screen.dart    (unchanged)
      room_setup_screen.dart   (unchanged)
```

## Gotchas / Notes

(Add anything discovered during refactoring that future sessions need to know)

- WebSocketServerService and WebSocketClientService are plain `Provider` singletons, not reactive. ChatNotifier needs to subscribe to their streams manually.
- EncryptionManager is a global singleton — chat notifier calls it directly.
- The file transfer "state machine" (offer → accept → chunks → complete) spans both sender and receiver. Sender tracks `_pendingFileOffers`, receiver tracks `_acceptedOffers`. Both need to be in the notifier.
- `_handleIncomingMessage` is the central router — it's a giant if/else on `data['type']`. During Phase 2b, we split this: message/ack/typing go to ChatNotifier, file types go to FileTransferNotifier (Phase 4), call types go to CallNotifier (Phase 5). The router itself can live in ChatNotifier and delegate.
- 4 AudioPlayer instances in chat_screen: `_audioPlayer`, `_ringtonePlayer`, `_notificationPlayer`, `_audioRecorder`. The ringtone/notification players relate to calls and notifications — they should move with their respective notifiers. The audio recorder relates to voice messages (file transfer).
- Platform channel `com.lanline.lanline/proximity` is used for ringtone/vibration on Android during calls. Stays with call handling.
