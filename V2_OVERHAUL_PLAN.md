# LANLine V2 Overhaul Plan

Date: 2026-03-23
Status: Active master plan
Purpose: This is the living document for the V2 overhaul. It should be updated throughout the project as phases are approved, started, completed, changed, or deferred.

## 1. How To Use This Document

This file is the main reference for the overhaul.

Use it for:

- the overall project goal
- the approved scope
- phase planning
- current progress
- decisions that have been locked
- changes in direction
- open questions and risks

Related documents:

- [V2_ARCHITECTURE.md](/C:/Users/Work/Documents/Coding%20Projects/Coding/Local-Chat/lanline/V2_ARCHITECTURE.md): stable design blueprint
- future implementation docs: concrete schemas, protocol specs, migration details

Rule of thumb:

- `V2_ARCHITECTURE.md` explains what V2 should be
- `V2_OVERHAUL_PLAN.md` tracks how we get there and where the project currently stands

## 2. Project Goal

Transform LANLine from a room-hosted ephemeral LAN chat app into a local-first messaging app with:

- direct messaging as the default experience
- persistent local history
- contact approval / permission model
- LAN and Tailscale reachability
- conversation list UI instead of room list UI
- file transfer and calls attached to conversations
- optional group chat later

## 3. Current Position

Current product shape:

- app now opens into a new V2 shell
- `Chats`, `People`, `Requests`, and `Settings` screens exist
- legacy room flow remains temporarily accessible from Settings
- V2 peer presence now starts from the shell and updates the local DB
- `People` is now contacts-only and `Requests` owns discovery/request actions
- remote request delivery and status sync now work between devices
- direct conversations now persist and exchange live text messages

Current project state:

- existing codebase has usable networking and feature foundations
- architecture direction has been drafted in `V2_ARCHITECTURE.md`
- Phase 1 through Phase 4 are implemented

## 4. Approved Direction

These are the current approved high-level decisions.

- V2 will be DM-first, not room-first
- stable device identity is required
- online/offline will mean reachable by LANLine, not internet-connected
- discovery must not automatically grant messaging permission
- persistent local history will be added
- rooms will not remain the main app concept
- group chat is likely a later phase, not the first V2 milestone

## 5. Scope Overview

### In Scope

- new core app model: peers, presence, conversations, messages, attachments
- contacts / request flow
- local database
- conversation list UI
- new app shell
- direct messaging
- migration of calls and file transfers to conversation-based behavior

### Out of Scope for Initial V2

- cloud/internet messaging
- remote push infrastructure
- multi-device account sync
- background delivery guarantees while app is fully closed
- polished final security redesign

## 6. Master Phase Plan

### Phase 0: Planning And Approval
Status: Complete

Goals:

- finalize product direction
- finalize architecture direction
- agree on the migration order

Deliverables:

- `V2_ARCHITECTURE.md`
- `V2_OVERHAUL_PLAN.md`
- agreed Phase 1 scope

Exit criteria:

- architecture accepted
- first implementation slice defined

### Phase 1: Foundation
Status: Complete

Goals:

- add stable local identity
- add database foundation
- add core data models and repositories

Expected deliverables:

- identity bootstrap
- database setup
- initial tables
- repository/provider structure
- first foundation tests

Exit criteria:

- app can initialize V2 identity and storage successfully
- no UI overhaul required yet

### Phase 2: New App Shell
Status: Complete

Goals:

- replace room-first entry flow
- introduce new top-level navigation and screens

Expected deliverables:

- `Chats`
- `People`
- `Requests`
- `Settings`

Exit criteria:

- app opens into the new shell
- old room flow is no longer the primary path

### Phase 3: Presence And Contact Requests
Status: Complete

Goals:

- implement peer discovery
- implement online/offline semantics
- implement contact approval flow

Expected deliverables:

- presence updates
- request acceptance/decline
- accepted contacts state

Exit criteria:

- users can discover peers and establish approved contact relationships

### Phase 4: Direct Messaging MVP
Status: Complete

Goals:

- create direct conversations
- persist and display messages
- power the chat list with real data

Expected deliverables:

- direct conversation creation
- conversation list previews
- unread counts
- message persistence

Exit criteria:

- the app works as a local messenger for direct chats

### Phase 5: Calls And File Transfer Migration
Status: Complete

Goals:

- rebind calls and file transfers to conversation/message models

Expected deliverables:

- file attachments tied to messages
- conversation-scoped calling

Exit criteria:

- core media features work from the new conversation model

### Phase 6: Group Chat Decision
Status: Not started

Goals:

- decide whether rooms become group conversations or are removed fully

Expected deliverables:

- group chat plan or room removal plan

Exit criteria:

- room-first leftovers have a final direction

### Phase 7: Cleanup And Hardening
Status: Not started

Goals:

- remove obsolete code
- reduce migration shims
- strengthen tests

Expected deliverables:

- dead code cleanup
- protocol cleanup
- regression coverage

Exit criteria:

- V2 is the default and legacy room architecture is no longer blocking progress

## 7. Immediate Next Step

The next implementation slice should start Phase 6:

- decide whether legacy rooms become V2 group chats or are removed
- define the migration path for old room-specific UI and transport code
- keep the legacy room path accessible only as long as Phase 6 requires it
- avoid growing two parallel group-chat concepts

## 8. Status Board

Use this section as the live session-by-session tracker.

### Overall

- Architecture direction: Drafted
- Master plan: Active
- Phase 1 implementation spec: Implemented
- Phase 2 app shell: Implemented
- Phase 3 presence and requests: Implemented
- Phase 4 direct messaging MVP: Implemented
- Phase 5 calls and file transfer migration: Implemented
- Implementation: In progress
- Current focus: Phase 6 group-chat direction

### Completed

- codebase scan and architecture assessment
- V2 architecture blueprint written
- V2 master overhaul plan written
- Phase 1 implementation spec written
- Drift/SQLite foundation added
- local identity bootstrap added
- V2 repositories and providers added
- Phase 1 tests added
- full analyze/test passing after Phase 1
- new V2 app shell added
- app entry moved to `Chats`, `People`, `Requests`, `Settings`
- legacy room flow moved behind Settings
- legacy room discovery kept intact while V2 peer presence was added
- V2 peer presence broadcasts/listening added to discovery service
- V2 presence controller added and started from the app shell
- `People` screen connected to discovered peers and contact actions
- `Requests` screen connected to incoming/outgoing request actions
- request repository now updates peer relationship state
- Phase 3 tests added for discovery parsing, presence controller writes, and request actions
- Windows discovery broadcast reliability improved with directed LAN targets
- V2 request signaling service added on a dedicated peer port
- incoming request records now sync across devices
- accept/decline/cancel/block now sync back to the sender
- Phase 3 protocol tests added for outbound request send and inbound request/status handling
- direct conversation screen added for V2 chats
- V2 direct message protocol added with delivery acknowledgements
- chat list now opens real V2 conversations backed by the local database
- message persistence, previews, unread counts, and delivery status are live
- Phase 4 tests added for outbound send and inbound direct-message handling
- attachment repository added on top of the V2 attachments table
- file transfers now create attachment records tied to V2 message records
- direct conversations now support file send/download actions from the V2 UI
- incoming calls now surface through the V2 app shell instead of the legacy room screen
- direct conversations now start audio/video calls through a V2 media protocol
- call summaries are now persisted in V2 conversations
- file-transfer buffering now keys by attachment/session ID instead of filename
- Phase 5 tests added for outbound file offers, inbound file offers, and incoming call state

### In Progress

- V2 overhaul implementation
- planning Phase 6 group-chat direction

### Pending

- Phase 6 group-chat decision
- Phase 7 cleanup and hardening

## 9. Decision Log

Add every major approved change here.

### 2026-03-23

- decided the overhaul should be phased, not a one-session rewrite
- decided V2 should be DM-first
- decided online/offline should mean reachable by LANLine
- decided contact permission is required before normal messaging
- decided to create a stable architecture blueprint plus a living overhaul plan
- decided to create a concrete Phase 1 implementation spec before code changes
- decided to keep the old room-first UI intact while V2 foundation is built beside it
- decided the old room flow should remain reachable through Settings during migration
- decided V2 peer presence should start from the app shell instead of waiting for the `People` tab to open
- decided Phase 5 should keep the existing WebRTC/file engines but move signaling and persistence onto V2 conversations and attachments

## 10. Change Log

Use this as the project history for the overhaul itself.

### 2026-03-23

- created `V2_ARCHITECTURE.md`
- created `V2_OVERHAUL_PLAN.md`
- created `V2_PHASE_1_IMPLEMENTATION.md`
- implemented V2 database foundation
- implemented local identity bootstrap on app startup
- added V2 repositories/providers for identity, peers, requests, conversations, and messages
- added Phase 1 tests for DB and identity bootstrap
- implemented Phase 2 V2 shell and legacy-room access path
- implemented Phase 3 peer presence/discovery updates
- implemented Phase 3 request actions in `People` and `Requests`
- added Phase 3 tests for discovery parsing, presence persistence, and request repository flows
- improved Windows LAN discovery reliability with directed broadcast targets
- implemented V2 request delivery and status sync between devices
- added V2 request protocol tests for outbound send and inbound request/status handling
- refactored discovery and request actions fully into the `Requests` tab
- implemented V2 direct-message protocol, conversation screen, and chat list navigation
- added Phase 4 tests for outgoing send and incoming message persistence/ack
- implemented Phase 2 app shell
- replaced the old main menu as the default entry point
- added temporary legacy access to rooms, join flow, and downloads from Settings
- implemented Phase 5 V2 media protocol for file transfer and direct calls
- added V2 attachment persistence and attachment repository coverage
- upgraded the V2 conversation screen with file actions and call actions
- added app-shell incoming-call handling for V2 conversations

## 11. Open Questions

These stay here until resolved.

1. Should initial DM delivery be live-only, or include pending outbox immediately?
2. Should Tailscale support be manual-address-first or more automated later?
3. Should group chat be explicitly deferred until DMs are stable?
4. Should old room screens remain temporarily hidden behind a migration/debug path?
5. How much of the current encryption model should remain unchanged during early V2 work?

## 12. Risks

- spending time on UI before the data model exists
- refactoring room logic too deeply before replacing the product model
- delaying stable identity too long
- designing cloud-like expectations into a serverless local-first system
- letting the docs become stale

## 13. Update Rules

This document should be updated when:

- a phase begins
- a phase completes
- scope changes
- a major technical decision is approved
- a major risk is found
- a document supersedes an earlier plan

Recommended update pattern after each meaningful session:

- update `Status Board`
- append to `Decision Log`
- append to `Change Log`
- revise phase notes if scope shifted
