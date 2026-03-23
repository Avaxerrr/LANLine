# LANLine V2 Architecture Blueprint

Date: 2026-03-23
Status: Draft for review
Scope: Product model, app structure, data model, presence semantics, migration plan

## 1. Purpose

This document defines the target architecture for LANLine V2.

V2 changes LANLine from a room-hosted ephemeral LAN chat app into a local-first messaging app with:

- direct messaging as the primary experience
- persistent local history
- contacts and connection requests
- LAN and Tailscale reachability
- optional group chat later

This document is meant to be reviewed before major implementation starts.

## 2. Current State Summary

The current app is built around a room model:

- one device hosts a room
- other devices join the room
- chat exists only inside that active room session
- messages are kept in memory only
- there is no stable peer identity
- discovery is room discovery, not peer discovery

The current architecture already has useful building blocks:

- Flutter + Riverpod
- WebSocket transport
- UDP discovery
- file transfer over WebSocket
- WebRTC calls
- feature-based folder structure

The main mismatch is not the technology stack. The mismatch is the app model.

## 3. Product Direction

### 3.1 Core Product Goal

LANLine V2 should behave like a conventional messenger within a local-only network model:

- users see a chat list, not a room list
- users connect to people/devices, not rooms
- conversations persist locally
- online/offline is based on reachability, not internet presence
- the app works on LAN and optionally Tailscale without requiring WAN/cloud infrastructure

### 3.2 Non-Goals for Initial V2

These are explicitly out of scope for the first V2 delivery:

- internet/cloud messaging
- push notifications via remote servers
- multi-device account sync
- strong cryptographic identity verification UI
- automatic background delivery while app is fully closed on all platforms

## 4. Core Domain Model

The app should move from `Room` to the following core entities.

### 4.1 Peer

A `Peer` is a known device/user identity.

It represents:

- a stable app/device identity
- a display name
- a visible fingerprint
- a relationship state with this device

Recommended fields:

- `peerId`: stable unique ID generated on first launch
- `displayName`
- `deviceLabel`
- `fingerprint`
- `avatarPath` nullable
- `relationshipState`
- `isBlocked`
- `createdAt`
- `updatedAt`
- `lastSeenAt` nullable

Notes:

- `peerId` must not depend on IP address or display name
- `displayName` is editable and not unique
- `fingerprint` is a short UI-safe identifier derived from the stable ID

### 4.2 Presence

A `Presence` record is runtime reachability state for a peer.

It answers:

- is this peer reachable right now
- by which transport/address
- when were they last seen

Recommended fields:

- `peerId`
- `isReachable`
- `transportType` such as `lan_broadcast` or `tailscale_direct`
- `host`
- `port`
- `lastHeartbeatAt`
- `lastProbeAt`
- `status`

Presence is not identity. A peer can exist in contacts while being offline for days.

### 4.3 Conversation

A `Conversation` is the chat thread shown in the chat list.

Types:

- `direct`
- `group` later

Recommended fields:

- `conversationId`
- `type`
- `title` nullable
- `createdAt`
- `updatedAt`
- `lastMessageAt` nullable
- `lastMessagePreview` nullable
- `unreadCount`
- `isArchived`
- `isMuted`

For a direct conversation, the members should be exactly:

- this device
- one peer

### 4.4 ConversationMember

This maps peers into conversations.

Recommended fields:

- `conversationId`
- `peerId`
- `role`
- `joinedAt`

This is required even if V2 initially focuses on direct messages because it makes group chat a natural extension later.

### 4.5 Message

A `Message` is a persistent event in a conversation.

Message types:

- `text`
- `system`
- `file`
- `voice_note`
- `call_summary`
- `connection_event`

Recommended fields:

- `messageId`
- `conversationId`
- `senderPeerId`
- `clientGeneratedId`
- `type`
- `textBody` nullable
- `status`
- `sentAt`
- `receivedAt` nullable
- `readAt` nullable
- `createdLocallyAt`
- `updatedAt`
- `replyToMessageId` nullable
- `metadataJson` nullable

Recommended status values:

- `pending`
- `sent`
- `delivered`
- `read`
- `failed`

### 4.6 Attachment

An `Attachment` stores metadata for a file/image/audio payload linked to a message.

Recommended fields:

- `attachmentId`
- `messageId`
- `kind`
- `fileName`
- `mimeType`
- `fileSize`
- `localPath` nullable
- `transferState`
- `checksum` nullable
- `width` nullable
- `height` nullable
- `durationMs` nullable

Recommended transfer state values:

- `pending_upload`
- `uploading`
- `pending_download`
- `downloading`
- `complete`
- `cancelled`
- `failed`

### 4.7 Contact Request

V2 should support permission before messaging.

Recommended fields:

- `requestId`
- `peerId`
- `direction` as `incoming` or `outgoing`
- `status`
- `createdAt`
- `respondedAt` nullable
- `message` nullable

Recommended status values:

- `pending`
- `accepted`
- `declined`
- `cancelled`
- `blocked`

### 4.8 Outbox Item

The app should prepare for queued delivery even if reconnect sync is deferred to a later phase.

Recommended fields:

- `outboxId`
- `messageId`
- `peerId`
- `attemptCount`
- `nextRetryAt` nullable
- `lastError` nullable
- `createdAt`

## 5. Identity Model

### 5.1 Local Device Identity

Each installation should generate and persist:

- `selfPeerId`
- `selfFingerprint`
- `selfDisplayName`
- optional `selfDeviceLabel`

Recommended generation:

- generate a random UUID or ULID on first launch
- derive a short fingerprint from the stable ID for UI display

Example:

- internal ID: `01HT...`
- visible fingerprint: `A4F2-91`

### 5.2 Why This Is Required

Without stable identity:

- names can collide
- IP addresses can change
- contacts cannot be trusted or re-associated correctly
- DMs cannot be modeled safely

## 6. Presence and Online/Offline Semantics

### 6.1 Definition of Online

In LANLine V2, `online` does not mean "device has internet."

It means:

`This peer is currently reachable by LANLine over LAN or Tailscale.`

This is the only practical and honest definition in a serverless local-first app.

### 6.2 Recommended Status Model

UI-facing statuses:

- `online`
- `recently_seen`
- `offline`
- `unknown`

Suggested interpretation:

- `online`: heartbeat seen recently
- `recently_seen`: seen recently but heartbeat expired
- `offline`: contact known but not currently reachable
- `unknown`: contact exists but has never been seen from this device

### 6.3 LAN Presence

Recommended LAN presence behavior:

- when the app is active, it broadcasts a heartbeat every 5-10 seconds
- when the app is active, it listens for peer heartbeats
- when a heartbeat is received, update `lastSeenAt`
- if no heartbeat is seen for 15-20 seconds, mark peer offline

This should be treated as app reachability, not physical device power state.

### 6.4 Tailscale Presence

Tailscale should not depend on LAN broadcast.

Recommended behavior:

- store known Tailscale IP or hostname per peer when available
- probe saved peers on app open, chat list open, conversation open, or when sending pending messages
- update `lastSeenAt` on successful response

### 6.5 Background Behavior

Initial V2 should assume:

- foreground or active app advertises/listens for presence
- fully closed app is treated as offline

This keeps the product honest and avoids platform-specific background complexity early on.

## 7. Relationship and Permission Model

Discovery must not equal trust.

Recommended peer relationship states:

- `discovered`
- `pendingIncoming`
- `pendingOutgoing`
- `accepted`
- `blocked`

Recommended rules:

- discovered peers may appear in a `People` screen
- a connection request is required before messaging/calling/file transfer
- accepted peers become contacts
- blocked peers cannot re-request or deliver content

This gives the app a private-messenger feel rather than an open LAN room.

## 8. User Experience Model

### 8.1 Primary Navigation

The old room-first navigation should be replaced.

Recommended tabs/screens:

- `Chats`
- `People`
- `Requests`
- `Settings`

Optional later:

- `Calls`

### 8.2 Chats

The `Chats` screen should show:

- conversation list
- last message preview
- unread badge
- online/recently seen indicator for direct messages
- pinned or archived state later

### 8.3 People

The `People` screen should show:

- nearby peers currently visible
- accepted contacts
- discovered but unapproved devices
- manual add/connect path for Tailscale peers

### 8.4 Requests

The `Requests` screen should show:

- incoming contact requests
- outgoing pending requests
- accept / decline / cancel actions

### 8.5 Settings

The `Settings` screen should manage:

- display name
- device label
- visible fingerprint
- LAN/Tailscale preferences
- future privacy and media preferences

## 9. Data Storage Recommendation

### 9.1 Database Choice

Recommended choice: Drift on top of SQLite.

Reasoning:

- strong typed schema
- good Flutter support
- migrations are manageable
- query composition is cleaner than raw `sqflite`
- suitable for message history and conversation lists

### 9.2 What Should Stay Out of SharedPreferences

SharedPreferences should only keep:

- small app settings
- the local identity bootstrap if needed before DB init

SharedPreferences should not remain the main storage for:

- message history
- conversations
- peers/contacts
- transfers

### 9.3 Initial Tables

Initial V2 schema should include:

- `local_identity`
- `peers`
- `presence`
- `contact_requests`
- `conversations`
- `conversation_members`
- `messages`
- `attachments`
- `outbox`

Optional later:

- `message_receipts`
- `sync_cursors`
- `group_invites`

## 10. Networking and Transport Direction

### 10.1 Keep Existing Foundations

The current tech choices remain valid:

- WebSocket for message/session transport
- UDP for LAN discovery/presence
- WebRTC for calls

### 10.2 Important Architectural Change

The transport should become peer-oriented rather than room-oriented.

Current model:

- host server
- room join
- one active session

Target model:

- each device has an identity
- devices discover peers
- devices create direct sessions
- conversations persist beyond any one socket session

### 10.3 Near-Term Practical Option

To avoid a total rewrite in one step, V2 can start with:

- one reachable app endpoint per device
- direct peer connection requests
- DM conversation mapped to peer sessions

This allows migration without inventing the final perfect transport immediately.

## 11. Message Delivery Model

### 11.1 Delivery Strategy

Recommended phased strategy:

Phase 1:

- send live messages only when peer is reachable
- save outgoing messages locally immediately
- mark unreachable sends as `pending` or `failed`

Phase 2:

- add outbox retry
- add peer-to-peer reconnect sync for missed messages

### 11.2 History Without a Central Server

There is no global source of truth.

That means:

- each device stores its own local copy
- a peer only has history it has already received or later synced
- history consistency is peer-to-peer, not server-authoritative

V2 should embrace this explicitly rather than imitating cloud messaging semantics.

## 12. File Transfer and Calls

### 12.1 File Transfer

The current file transfer logic is reusable but should be re-bound to:

- `conversationId`
- `messageId`
- `attachmentId`

instead of room/session assumptions.

### 12.2 Calls

Calls should become conversation-scoped or peer-scoped rather than room-scoped.

Recommended call targets:

- direct call from a direct conversation
- group call later from a group conversation

### 12.3 Important Future Fix

Current incoming file chunk buffering is keyed by filename. This should move to a transfer/session ID to avoid collisions when filenames repeat.

## 13. Security and Privacy Direction

### 13.1 Short-Term

Retain optional encryption support, but tighten the model later.

### 13.2 Known Limitation

The current password-based encryption implementation is not a long-term final security design.

Later improvements should consider:

- per-session nonce or IV usage
- stronger key derivation
- optional peer trust verification

This should not block V2 product migration, but it should not be considered finished security work.

## 14. Target Code Organization

Recommended structure:

```text
lib/
  app/
    app_shell.dart
    routes.dart
  core/
    db/
      app_database.dart
      tables/
      daos/
    identity/
      local_identity_service.dart
    models/
    networking/
      discovery/
      transport/
      protocol/
    repositories/
    services/
    theme/
  features/
    chats/
      application/
      presentation/
    people/
      application/
      presentation/
    requests/
      application/
      presentation/
    settings/
      application/
      presentation/
    conversation/
      application/
      presentation/
    calls/
      application/
      presentation/
    transfers/
      application/
      presentation/
```

Notes:

- not every layer has to be fully formal on day one
- repositories should be introduced before large UI rewrites
- old room-related files can coexist during migration

## 15. Migration Strategy

V2 should be implemented in slices while the app remains runnable.

### Phase 0: Blueprint and Decisions

Deliverables:

- approve this document
- resolve open questions
- define the first implementation slice

### Phase 1: Foundation

Deliverables:

- stable local identity generation
- Drift database setup
- core tables
- repositories for peers, conversations, messages

No major UI rewrite yet.

### Phase 2: New App Shell

Deliverables:

- replace room-first home with new tab shell
- scaffold `Chats`, `People`, `Requests`, `Settings`
- keep old room features available behind a temporary path if needed

### Phase 3: Presence and Requests

Deliverables:

- peer discovery
- online/offline status based on reachability
- contact request flow
- accepted contacts list

### Phase 4: Direct Messaging MVP

Deliverables:

- create direct conversation
- send/store/load messages
- conversation list previews
- unread counts

At this point the app becomes functionally a messenger.

### Phase 5: Attachments and Calls Migration

Deliverables:

- file transfer bound to conversations/messages
- call flow initiated from direct conversations

### Phase 6: Group Chat Decision

Choose one:

- remove rooms completely
- or evolve rooms into group conversations

### Phase 7: Cleanup

Deliverables:

- delete obsolete room-first code
- clean protocol edge cases
- harden tests

## 16. What Stays vs What Changes

### Keep

- Flutter
- Riverpod
- WebSocket transport foundation
- UDP discovery foundation
- WebRTC call foundation
- file transfer foundation

### Replace or Rework

- `Room` as the primary user-facing concept
- room list home flow
- join-room main onboarding
- in-memory-only message state
- SharedPreferences-backed app data beyond simple settings
- room-centric status labels and UI language

### Likely Remove Later

- `My Rooms` home action
- `Join Room` primary flow
- room setup UI as a main feature

Potentially keep only if turned into group chat admin later.

## 17. Risks and Constraints

Main risks:

- trying to redesign UI before the data model exists
- mixing room-based transport assumptions into the new DM architecture
- not having stable identity before building contacts
- overpromising cloud-like behavior without a central server
- background presence expectations on mobile platforms

Main constraint:

V2 must be honest about what `online`, `history`, and `delivery` mean in a local-first serverless system.

## 18. Open Questions

These should be answered before or during early implementation:

1. Should V2 messaging MVP allow only live delivery, or also queue pending messages immediately?
2. Should accepted contacts be stored automatically on request approval, or should there be an explicit "save contact" distinction?
3. Should group chat be part of V2 initial delivery, or deferred until DMs are stable?
4. Should Tailscale peers be manually added by address/hostname, or also supported through a richer discovery/import flow later?
5. How much of the current encryption model should be retained during migration before a later security pass?

## 19. Recommended Next Step

The next implementation document should define the concrete V2 data schema and first migration slice:

- exact Drift tables
- provider and repository ownership
- app shell navigation
- identity bootstrap flow
- presence protocol packet shape

That should be followed by implementation of Phase 1 foundation work.
