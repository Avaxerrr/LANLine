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
- [x] Create `lib/features/chat/presentation/widgets/chat_message_bubble.dart`
- [x] Move `_buildMessageBubble`, `_buildMessageContent`, `_buildFileBubble`
- [x] Move `_formatTimestamp`, `_showMessageOptions`
- [x] `flutter analyze` passes

#### Phase 3b: Input bar
- [x] Create `lib/features/chat/presentation/widgets/chat_input_bar.dart`
- [x] Move `_buildMessageInput`, attachment menu, recording state
- [x] `flutter analyze` passes

#### Phase 3c: Room info panel
- [x] Create `lib/features/chat/presentation/widgets/chat_room_info_panel.dart`
- [x] Move `_showRoomInfoPanel`, `_infoTile`, `_participantRow`
- [x] `flutter analyze` passes

#### Phase 3 verification
- [ ] Manual test: visual check, all UI elements render correctly

### Phase 4: Extract FileTransferNotifier
- [x] Create `lib/core/providers/file_transfer_notifier.dart`
- [x] Move offer/accept/cancel state machine
- [x] Move `_pendingFileOffers`, `_downloadProgress`, `_cancelledOffers`, `_acceptedOffers`
- [x] Move `_sendFile()`, `_acceptFileOffer()`, `_cancelFileOffer()`
- [x] Move file-related handlers from incoming message router
- [x] Write tests: `test/core/providers/file_transfer_notifier_test.dart`
- [x] `flutter analyze` + `flutter test` pass
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

### Phase 2b - 2026-03-22
Status: Complete
- Moved `handleIncomingMessage()` into ChatNotifier (handles message, ack, typing, participant_list, room_closed, error, call_summary, clipboard; returns null for call/file types)
- Widget's `_handleIncomingMessage` now routes through notifier first, then handles call/file types locally
- Replaced local `_messages` field with bridge getter reading from `ref.read(chatProvider).messages`
- Replaced local `_participantCount`, `_participantNames`, `_roomClosed` fields with bridge getters
- Removed `_typingUsers` bridge getter (only used in build, replaced with `chatState.typingUsers`)
- Added `ref.watch(chatProvider)` in build() for reactive rebuilds — widget no longer needs setState for message/participant/typing changes
- All `_messages.add()` / `_messages[i] = ...` mutations replaced with notifier methods (addMessage, updateMessageAt, updateMessageByOfferId)
- Participant tracking in initState updated to go through notifier
- Removed local `_participantCount = 1` init for clients (handled by notifier.init)
- 17 new tests for handleIncomingMessage (message, ack, typing, participant_list, room_closed, error, clipboard, call_summary, call/file type delegation, invalid JSON)
- Total tests: 58, all passing
- Gotcha: `ref.watch` in build + `ref.read` in event handlers is the correct Riverpod pattern. Bridge getters use `ref.read` for non-build contexts.

### Phase 2c - 2026-03-22
Status: Complete
- Moved participant count stream subscription (host) into ChatNotifier.init()
- Moved client disconnect handler into ChatNotifier.init() — triggers markRoomClosed + onRoomClosed callback
- Added ChatNotifier.dispose() to cancel subscription and clear handlers
- Widget no longer owns _participantSubscription — removed field entirely
- Widget registers onRoomClosed callback for UI (showing dialog)
- MockWebSocketClient now stores onDisconnected field for testability
- 8 new tests: host subscription, reactive updates, client disconnect, idempotent close, dispose cleanup
- Total tests: 66, all passing
- Gotcha: mocktail Mock doesn't store field values by default. Override onDisconnected as a real field in the mock class.

### Phase 3 - 2026-03-23
Status: Complete
- **Phase 3a**: Extracted message bubble to `widgets/chat_message_bubble.dart` (543 lines)
  - Moved `_buildMessageBubble`, `_buildMessageContent`, `_buildFileBubble`, `_fileActionButton`, `_showMessageOptions`, `_formatTimestamp`, `_formatFileSize`, `_getMimeType`, `_openFile`, `_openFolder`, `_shareFile`
  - Exported `formatFileSize()` as public top-level function (still referenced by chat_screen for file offer/send)
  - Removed unused imports: open_filex, flutter_linkify, url_launcher, share_plus
- **Phase 3b**: Extracted input bar to `widgets/chat_input_bar.dart` (248 lines)
  - `ChatInputBar` (StatelessWidget): text field, attachment/clipboard/send buttons
  - `AttachmentMenu` (StatelessWidget): grid of file/gallery/camera/clipboard/voice options
  - Moved `_buildMessageInput`, `_showAttachmentMenu`, `_attachmentGridItem`
- **Phase 3c**: Extracted room info panel to `widgets/chat_room_info_panel.dart` (161 lines)
  - Top-level `showRoomInfoPanel()` function with modal bottom sheet
  - Moved `_showRoomInfoPanel`, `_participantRow`, `_infoTile`
  - Removed unused import: qr_flutter from chat_screen.dart
- chat_screen.dart reduced from ~1800 → 1029 lines
- Total tests: 66, all passing

### Phase 4 - 2026-03-23
Status: Complete
- Created `FileTransferNotifier` with `FileTransferState` in `core/providers/file_transfer_notifier.dart`
- Moved all file transfer state: `pendingFileOffers`, `downloadProgress`, `cancelledOffers`, `acceptedOffers`, progress throttle timer
- Moved `sendFile`, `acceptFileOffer`, `cancelFileOffer` to notifier
- Moved file message handling: `file_chunk`, `file_offer`, `accept_file`, `file_downloaded`, `cancel_file`
- Moved `_logDownload` to notifier (uses `downloadHistoryProvider`)
- Moved `formatFileSize` from `chat_message_bubble.dart` to `core/models/chat_message.dart` (shared by notifier and widget)
- Removed `_messages` bridge getter (no longer needed)
- Removed unused imports: `file_transfer_manager.dart`, `download_history_provider.dart` from chat_screen
- Widget thin wrappers: `_sendFile` → `notifier.sendFile`, `_acceptFileOffer` → `notifier.acceptFileOffer`, `_cancelFileOffer` → `notifier.cancelFileOffer`
- Widget watches `fileTransferNotifierProvider` for `downloadProgress` in build
- File message routing: widget calls `notifier.handleFileMessage(rawMessage)`, handles UI side-effects (scroll, notification, snackbar) based on return type
- chat_screen.dart reduced from 1029 → 836 lines
- 20 new tests for FileTransferNotifier
- Total tests: 86, all passing

### NEXT: Phase 5 (extract CallNotifier)

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
