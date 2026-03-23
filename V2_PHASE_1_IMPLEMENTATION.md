# LANLine V2 Phase 1 Implementation Spec

Date: 2026-03-23
Status: Implemented
Scope: Concrete implementation plan for Phase 1 foundation work

## 1. Purpose

This document defines the first implementation slice for the V2 overhaul.

Phase 1 does not attempt to deliver the new messenger UI yet.

Phase 1 only establishes the foundation required for all later phases:

- stable local identity
- local database
- initial V2 entities and tables
- repository boundaries
- Riverpod provider ownership
- migration boundary between old room-based code and new V2 code

This document should be specific enough to code from directly.

## 2. Phase 1 Goal

At the end of Phase 1, the app should:

- generate and persist a stable local identity
- initialize a V2 database successfully
- expose repositories/providers for peers, conversations, messages, and requests
- allow the old app to keep running while the new V2 foundation exists beside it

Phase 1 is successful if the codebase can support later V2 work without yet replacing the old room-first product flow.

## 3. Deliverables

Required deliverables:

- Drift database setup
- local identity bootstrap and persistence
- initial schema tables
- data classes / table mappings
- repository interfaces and first implementations
- Riverpod providers for identity and repositories
- basic tests for DB bootstrap and identity creation

Not included in Phase 1:

- new `Chats` / `People` UI
- conversation list UI
- peer presence transport
- request acceptance UI
- direct messaging transport changes

## 4. Recommended Technical Choice

### 4.1 Database

Use Drift with SQLite.

Recommended packages to add later during implementation:

- `drift`
- `sqlite3_flutter_libs`
- `path_provider`
- `path`
- `drift_dev` in dev dependencies
- `build_runner` in dev dependencies

Reason:

- typed schema
- migration support
- good fit for Flutter desktop and Android
- much better long-term structure than continuing with SharedPreferences

### 4.2 Identity Generation

Use a randomly generated stable ID on first launch.

Recommended package:

- `uuid`

Recommended approach:

- generate a UUID v4 on first V2 initialization
- store it in the database as the canonical local identity
- derive a short fingerprint from the ID for UI use

## 5. Directory Plan For Phase 1

Add the following structure:

```text
lib/
  core/
    db/
      app_database.dart
      app_database.g.dart
      tables/
        local_identity_table.dart
        peers_table.dart
        presence_table.dart
        contact_requests_table.dart
        conversations_table.dart
        conversation_members_table.dart
        messages_table.dart
        attachments_table.dart
        outbox_table.dart
      daos/
        identity_dao.dart
        peers_dao.dart
        conversations_dao.dart
        messages_dao.dart
        requests_dao.dart
    identity/
      identity_service.dart
      fingerprint_service.dart
    repositories/
      identity_repository.dart
      peers_repository.dart
      conversations_repository.dart
      messages_repository.dart
      requests_repository.dart
    providers/
      v2_database_provider.dart
      v2_identity_provider.dart
      v2_repository_providers.dart
```

Notes:

- do not remove existing room providers yet
- do not move the whole app at once
- Phase 1 should coexist with current code

## 6. Schema Specification

The schema below is the minimum recommended V2 foundation.

## 6.1 `local_identity`

Purpose:

- stores this installation's identity

Recommended columns:

- `id` TEXT PRIMARY KEY
- `peer_id` TEXT NOT NULL UNIQUE
- `display_name` TEXT NOT NULL
- `device_label` TEXT
- `fingerprint` TEXT NOT NULL
- `created_at` INTEGER NOT NULL
- `updated_at` INTEGER NOT NULL

Rules:

- exactly one row should exist
- if no row exists on app startup, create one
- initial `display_name` may be seeded from existing username

Notes:

- the existing `usernameProvider` value should be used as the initial migration source if present
- after V2 matures, username management should move to the DB-backed identity flow

## 6.2 `peers`

Purpose:

- stores known peers and contacts

Recommended columns:

- `id` TEXT PRIMARY KEY
- `peer_id` TEXT NOT NULL UNIQUE
- `display_name` TEXT NOT NULL
- `device_label` TEXT
- `fingerprint` TEXT
- `relationship_state` TEXT NOT NULL
- `is_blocked` INTEGER NOT NULL DEFAULT 0
- `last_seen_at` INTEGER
- `created_at` INTEGER NOT NULL
- `updated_at` INTEGER NOT NULL

Recommended enum values for `relationship_state`:

- `discovered`
- `pending_incoming`
- `pending_outgoing`
- `accepted`
- `blocked`

## 6.3 `presence`

Purpose:

- stores the latest known runtime reachability of a peer

Recommended columns:

- `id` TEXT PRIMARY KEY
- `peer_id` TEXT NOT NULL
- `status` TEXT NOT NULL
- `transport_type` TEXT
- `host` TEXT
- `port` INTEGER
- `last_heartbeat_at` INTEGER
- `last_probe_at` INTEGER
- `is_reachable` INTEGER NOT NULL DEFAULT 0
- `updated_at` INTEGER NOT NULL

Recommended enum values for `status`:

- `unknown`
- `online`
- `recently_seen`
- `offline`

Notes:

- keep `presence` separate from `peers`
- `peers.last_seen_at` is useful for denormalized UI and sorting

## 6.4 `contact_requests`

Purpose:

- stores connection approval requests

Recommended columns:

- `id` TEXT PRIMARY KEY
- `peer_id` TEXT NOT NULL
- `direction` TEXT NOT NULL
- `status` TEXT NOT NULL
- `message` TEXT
- `created_at` INTEGER NOT NULL
- `responded_at` INTEGER
- `updated_at` INTEGER NOT NULL

Recommended enum values:

For `direction`:

- `incoming`
- `outgoing`

For `status`:

- `pending`
- `accepted`
- `declined`
- `cancelled`
- `blocked`

## 6.5 `conversations`

Purpose:

- stores direct and later group threads

Recommended columns:

- `id` TEXT PRIMARY KEY
- `type` TEXT NOT NULL
- `title` TEXT
- `last_message_preview` TEXT
- `last_message_at` INTEGER
- `unread_count` INTEGER NOT NULL DEFAULT 0
- `is_archived` INTEGER NOT NULL DEFAULT 0
- `is_muted` INTEGER NOT NULL DEFAULT 0
- `created_at` INTEGER NOT NULL
- `updated_at` INTEGER NOT NULL

Recommended enum values for `type`:

- `direct`
- `group`

## 6.6 `conversation_members`

Purpose:

- maps peers to conversations

Recommended columns:

- `id` TEXT PRIMARY KEY
- `conversation_id` TEXT NOT NULL
- `peer_id` TEXT NOT NULL
- `role` TEXT NOT NULL
- `joined_at` INTEGER NOT NULL

Recommended enum values for `role`:

- `member`
- `admin`

Recommended unique constraint:

- unique pair of `conversation_id` + `peer_id`

## 6.7 `messages`

Purpose:

- stores persistent conversation events

Recommended columns:

- `id` TEXT PRIMARY KEY
- `conversation_id` TEXT NOT NULL
- `sender_peer_id` TEXT NOT NULL
- `client_generated_id` TEXT NOT NULL UNIQUE
- `type` TEXT NOT NULL
- `text_body` TEXT
- `status` TEXT NOT NULL
- `reply_to_message_id` TEXT
- `metadata_json` TEXT
- `sent_at` INTEGER
- `received_at` INTEGER
- `read_at` INTEGER
- `created_locally_at` INTEGER NOT NULL
- `updated_at` INTEGER NOT NULL

Recommended enum values for `type`:

- `text`
- `system`
- `file`
- `voice_note`
- `call_summary`
- `connection_event`

Recommended enum values for `status`:

- `pending`
- `sent`
- `delivered`
- `read`
- `failed`

## 6.8 `attachments`

Purpose:

- stores attachment metadata

Recommended columns:

- `id` TEXT PRIMARY KEY
- `message_id` TEXT NOT NULL
- `kind` TEXT NOT NULL
- `file_name` TEXT NOT NULL
- `mime_type` TEXT
- `file_size` INTEGER NOT NULL
- `local_path` TEXT
- `transfer_state` TEXT NOT NULL
- `checksum` TEXT
- `width` INTEGER
- `height` INTEGER
- `duration_ms` INTEGER
- `created_at` INTEGER NOT NULL
- `updated_at` INTEGER NOT NULL

Recommended enum values:

For `kind`:

- `file`
- `image`
- `audio`
- `video`

For `transfer_state`:

- `pending_upload`
- `uploading`
- `pending_download`
- `downloading`
- `complete`
- `cancelled`
- `failed`

## 6.9 `outbox`

Purpose:

- stores pending outgoing delivery tasks

Recommended columns:

- `id` TEXT PRIMARY KEY
- `message_id` TEXT NOT NULL
- `peer_id` TEXT NOT NULL
- `attempt_count` INTEGER NOT NULL DEFAULT 0
- `next_retry_at` INTEGER
- `last_error` TEXT
- `created_at` INTEGER NOT NULL
- `updated_at` INTEGER NOT NULL

## 7. DAO Ownership

The first DAOs should be narrow and table-focused.

Recommended DAO responsibilities:

### `IdentityDao`

- get local identity
- insert initial identity
- update local display name / device label

### `PeersDao`

- insert or upsert peer
- update relationship state
- update last seen
- query contacts
- query discovered peers

### `RequestsDao`

- create outgoing request
- create or upsert incoming request
- update request status
- query pending requests

### `ConversationsDao`

- create conversation
- add conversation member
- find direct conversation by peer
- update conversation preview and unread count
- query conversation list

### `MessagesDao`

- insert message
- update message status
- query messages by conversation
- append system event

### `AttachmentsDao`

- insert attachment
- update transfer state
- query attachments by message

## 8. Repository Ownership

Repositories should sit above DAOs and become the interface used by features.

### `IdentityRepository`

Responsibilities:

- bootstrap local identity
- expose current local identity
- update local profile fields

### `PeersRepository`

Responsibilities:

- create/upsert peers
- manage relationship states
- expose accepted contacts
- expose discovered peers
- update presence and last seen

### `RequestsRepository`

Responsibilities:

- create outgoing requests
- receive incoming requests
- accept/decline/cancel/block

### `ConversationsRepository`

Responsibilities:

- create direct conversations
- load conversation list
- find or create direct conversation for peer
- update unread and preview state

### `MessagesRepository`

Responsibilities:

- insert outgoing message locally
- insert incoming message locally
- load messages for conversation
- update send/delivery/read status

## 9. Provider Ownership

Keep provider boundaries simple and explicit.

### Database

- `appDatabaseProvider`

Provides the singleton Drift database.

### Identity

- `identityRepositoryProvider`
- `localIdentityProvider`

`localIdentityProvider` should expose the current local identity as async state.

### Peers

- `peersRepositoryProvider`
- `contactsProvider`
- `discoveredPeersProvider`

### Requests

- `requestsRepositoryProvider`
- `pendingIncomingRequestsProvider`
- `pendingOutgoingRequestsProvider`

### Conversations

- `conversationsRepositoryProvider`
- `conversationListProvider`

### Messages

- `messagesRepositoryProvider`
- family provider like `conversationMessagesProvider(conversationId)`

Notes:

- do not connect these yet to the old `chatProvider`
- Phase 1 only establishes the ownership map

## 10. Identity Bootstrap Flow

This should be the first real runtime flow implemented in Phase 1.

### On app startup

1. initialize the database
2. query `local_identity`
3. if a row exists, load it
4. if no row exists:
   - read existing username from SharedPreferences if available
   - generate `peerId`
   - derive fingerprint
   - create `local_identity` row
5. expose the local identity through Riverpod

### Initial naming behavior

Recommended rule:

- if the old username exists, use it as the initial `displayName`
- otherwise use a generic default like `LANLine User`

### Fingerprint behavior

Recommended rule:

- fingerprint is derived and stable
- user cannot edit it
- show it later in settings and contact verification UI

## 11. Migration Boundary

Phase 1 must not try to replace the old room app immediately.

### What stays untouched in Phase 1

- `main.dart` home flow
- room list
- room setup
- client scanner
- current chat room screen
- current call flow
- current file transfer flow

### What gets added in Phase 1

- new V2 DB and repositories
- identity bootstrap
- V2 providers
- tests

### Why

This keeps the app runnable and avoids a high-risk rewrite while the new foundation is still being built.

## 12. Initial Testing Scope

Phase 1 should add focused tests.

Recommended tests:

- DB initializes successfully
- local identity is created on first run
- local identity re-loads on second run
- old SharedPreferences username seeds initial display name
- peer upsert works
- direct conversation creation works
- message insertion/query works

No end-to-end messaging test is required yet for Phase 1.

## 13. Implementation Order

Recommended order of execution:

1. add dependencies
2. create Drift database and tables
3. create DAOs
4. create repositories
5. implement identity bootstrap
6. add providers
7. add tests
8. optionally add a temporary debug screen or logs to verify the new foundation

## 14. Acceptance Criteria

Phase 1 is done when all of the following are true:

- V2 database exists and opens correctly
- local identity is bootstrapped and persisted
- initial V2 repositories compile and are usable
- conversation/message data can be inserted and queried locally
- the old app still runs
- tests cover the new foundation adequately

## 15. Deferred To Phase 2+

These items are intentionally deferred:

- new tabs and shell UI
- nearby people screen
- online/offline heartbeat wiring
- request approval UI
- actual DM socket transport
- outbox retry behavior
- history sync

## 16. Recommended First Coding Slice

If this document is approved, the first coding slice should be:

- add Drift-related dependencies
- create `app_database.dart`
- implement `local_identity` table
- implement `IdentityDao`
- implement `IdentityRepository`
- add `appDatabaseProvider` and `localIdentityProvider`
- wire app startup to bootstrap identity without changing the visible UI yet

That gives the overhaul its first real backbone with minimal product risk.

## 17. Document Update Rule

When Phase 1 implementation starts, update:

- [V2_OVERHAUL_PLAN.md](/C:/Users/Work/Documents/Coding%20Projects/Coding/Local-Chat/lanline/V2_OVERHAUL_PLAN.md)

with:

- phase status
- concrete tasks started/completed
- new decisions or deviations from this spec
