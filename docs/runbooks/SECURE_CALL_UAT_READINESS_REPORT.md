# SECURE CALL UAT READINESS REPORT

Date: 2026-05-12

## Result

PARTIAL - PRE-PROVIDER LOGIC HARDENED, LIVE CALL BLOCKED.

## Changed

- `initiate-call`
  - Requires authenticated caller.
  - Requires active org/user context.
  - Requires strict `can_call_leads` permission.
  - Requires active call data loan.
  - Checks consent and DND before contact decryption.
  - Fails clearly with `provider_config_missing` if Exotel callback/provider config is absent.
  - Does not return contact data.
- `broker-self-secure-call`
  - Now also requires an active call data loan.
  - Fails closed on missing provider config before decryption.
  - Does not return contact data.
- `broker-upload-lead`
  - Fails with `secure_config_missing` if `PHONE_ENCRYPTION_KEY` is unavailable.

## Verified

- Trust-loop UAT proved:
  - broker lead upload response did not expose contact data
  - `leads_sensitive` is not readable by broker anon client
  - duplicate prevention works
  - SM public lead visibility works

## Blocked

- Caller sign-in failed with invalid test credentials.
- Exotel provider secrets are absent locally and remotely.
- `CALLER_INVITE_CODE` is absent remotely, so new caller onboarding will fail closed.

## Verdict

Secure-call code is safer than before this pass, but live secure-call UAT is not ready until caller identity and provider secrets are fixed.
