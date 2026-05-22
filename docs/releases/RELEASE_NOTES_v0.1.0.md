# Release Notes - v0.1.0

## Sprint 1: Masked Dialer Enforcement Spine

This release establishes the "Trustless" data enforcement layer for the Sourcing Manager OS.

### Features

- **Encrypted Lead Storage**: Phone numbers are encrypted using pgcrypto (AES-256) at rest.
- **Data Loan System**: Temporary access tokens for lead interaction, preventing data scraping.
- **Masked Dialer**: PSTN bridging via Exotel ensures callers never see customer numbers.
- **Append-Only Auditing**: Immutable logs for all sensitive system events.
- **Enforced Privacy**: Default-deny RLS policies on all tables.

### Security Guarantees

- **Zero Visibility**: No phone numbers are returned in API responses or displayed in the UI.
- **Edge Decryption**: Decryption occurs only in the short-lived memory of Supabase Edge Functions.
- **Automatic Wiping**: Sensitive memory references are nulled immediately after use.
- **Constitution Scan**: CI/CD pipeline integrated with a security scanner to block forbidden terms.

### Known Limitations

- Site visits are currently self-reported (Verification Engine coming in Sprint 2).
- Only Exotel (India) is supported as the primary PSTN bridge.
- Broker locks are manual skeletons in this release.

### Manual Setup Required

- Supabase Project creation (India region).
- Exotel API key and Caller ID verification.
- Environment variables configuration (see DEPLOYMENT.md).

### Next Sprint Scope

**Sprint 2: Site Visit Verification Engine**

- GPS and Geofence validation.
- Live photo capture with hash proofs.
- Evidence-backed broker commission locks.
