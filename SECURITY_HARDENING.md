# Security Hardening Notes

This project is a local-first messenger for LAN and Tailscale-style private networking. It does not currently provide strong end-to-end cryptographic identity verification.

## Current posture

- Incoming signaling payloads are now size-limited and basic protocol fields are validated before they are trusted.
- Direct messages are accepted only from trusted peers already known through the contact flow.
- Group invites and group messages are accepted only from trusted peers with valid conversation membership.
- SQLite indexes were added for the highest-traffic tables to keep presence, conversation, and message queries responsive as local history grows.
- Local conversation/message text is encrypted before being written to SQLite, but the encryption keys are currently stored via app preferences for cross-platform compatibility.

## Important limitations

- Discovery and signaling are still trust-on-first-contact, not signed identity.
- Local SQLite data is no longer plaintext, but key storage is not OS-secure on desktop/mobile in the current implementation.
- File and message transport still assume a trusted local/private network.

## Recommended future work

1. Add signed device identity for discovery and signaling.
2. Upgrade key storage to OS-backed secure storage or a desktop-specific secure store.
3. Add replay protection or message-authentication tokens for protocol frames.
4. Add message pagination and retention controls for large histories.

## Removed unsafe legacy code

The old password-based `EncryptionManager` was removed because it was unused and relied on insecure construction choices, including deterministic key derivation and a fixed IV. Any future encryption feature should be implemented as a new, explicitly reviewed design.
