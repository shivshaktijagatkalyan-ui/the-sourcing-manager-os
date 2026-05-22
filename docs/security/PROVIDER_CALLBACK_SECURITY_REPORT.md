# PROVIDER CALLBACK SECURITY REPORT

Date: 2026-05-12

## Result

CODE HARDENED, LIVE PROVIDER BLOCKED.

`exotel-callback` was hardened, deployed, and given database replay support. Live provider callback UAT is still blocked because Exotel secrets and `EXOTEL_CALLBACK_SECRET` are not configured remotely.

## Changed

- `exotel-callback/index.ts`
  - Requires signed callback URLs using `callback_token`.
  - Verifies token with HMAC-SHA256 over `attempt_id`.
  - Rejects missing/invalid callback auth.
  - Rejects replayed callback event hashes.
  - Enforces strict call state transitions.
  - Does not persist raw provider payload.
  - Writes safe audit events for accepted/rejected callbacks when an attempt is known.
- `initiate-call/index.ts`
  - Adds signed callback token to provider callback URL.
  - Fails with `provider_config_missing` before decrypting contact data when provider config is absent.
- `broker-self-secure-call/index.ts`
  - Adds signed callback token to provider callback URL.
  - Fails with `provider_config_missing` before decrypting contact data when provider config is absent.
- Database migration added callback replay columns and unique event hash index.

## Verified

- Remote database has `callback_event_hash`, `callback_received_at`, and `callback_failure_reason`.
- Functions were redeployed.
- Fake callback UAT could not be completed because caller sign-in is blocked before a call attempt can be created.

## Blockers

Remote secrets missing:

- `EXOTEL_SID`
- `EXOTEL_API_KEY`
- `EXOTEL_API_TOKEN`
- `EXOTEL_CALLER_ID`
- `EXOTEL_CALLBACK_SECRET`

## Verdict

The callback endpoint is no longer an open state update endpoint in code. Live proof remains blocked until provider secrets and a valid caller account exist.
