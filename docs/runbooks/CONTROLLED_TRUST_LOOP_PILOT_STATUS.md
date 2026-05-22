# CONTROLLED TRUST LOOP PILOT STATUS

Date: 2026-05-12

## 1. Executive Summary

Verdict: B. PARTIAL - PROVIDER/CONFIG BLOCKERS REMAIN

The project moved materially closer to controlled trust-loop pilot readiness. Core broker intake and isolation pieces are now live-proven:

- broker sign-in
- server-governed broker onboarding
- encrypted lead upload
- sensitive table denial from frontend anon client
- duplicate prevention
- sourcing manager metadata visibility
- PII-safe broker-visible audit event
- function/config drift check
- web and APK release builds

But the complete trust loop is not proven. The live UAT is blocked at caller sign-in, and provider secrets remain missing.

## 2. What is Proven

- Production DB migrations are up to date.
- 47 function directories match `supabase/config.toml`.
- New callback replay columns exist remotely.
- New sourcing-manager lead and broker-lock RLS policies exist remotely.
- Broker onboarding through `complete-onboarding` passed.
- Broker lead upload passed.
- Uploaded lead response did not expose contact data.
- Broker anon client could not read `leads_sensitive`.
- Duplicate upload was blocked.
- Assigned sourcing manager could read public lead metadata.
- Audit trail response was PII-safe.
- `python scripts/security-check.py` passed.
- `npx tsc --noEmit` passed.
- `flutter analyze` passed.
- `flutter build web --release` passed.
- `flutter build apk --release` passed.

## 3. What is Blocked

- Caller test credentials are invalid.
- Remote Exotel provider secrets are missing.
- Remote `EXOTEL_CALLBACK_SECRET` is missing.
- Remote `CALLER_INVITE_CODE` is missing.
- Secure call cannot be live-proven.
- Provider callback rejection cannot be live-proven against a real attempt.
- Follow-up update cannot be live-proven because caller sign-in is blocked.
- Site visit proof cannot be live-proven in the current trust-loop sequence.
- Broker lock creation cannot be live-proven in the current trust-loop sequence.

## 4. What is Still Demo/Training

Training mode still exists for local/dev builds, but production release builds no longer honor training URL/storage/mock-role overrides by default.

No new dashboard, AI, payout, WhatsApp, tel, or export feature was added.

## 5. Trust Loop UAT Result

Result: BLOCKED.

Passed:

- broker sign-in
- broker onboarding
- broker lead upload
- sensitive table denial
- duplicate prevention
- sourcing manager visibility
- audit response hygiene

Blocked:

- caller sign-in
- caller assignment/data loan
- secure call
- provider callback
- call outcome/follow-up
- site visit proof
- broker lock

Report: `TRUST_LOOP_UAT_REPORT.md`

## 6. Broker Isolation Result

Result: PARTIAL PASS.

The live UAT proved a broker cannot read `leads_sensitive`, and the assigned sourcing manager can read only public lead metadata. Full broker A vs broker B cross-read denial was not live-tested because a second broker test identity was not available.

## 7. Callback Security Result

Result: CODE HARDENED, LIVE TEST BLOCKED.

`exotel-callback` now requires signed callback tokens, rejects replay hashes, and enforces strict transitions. Live callback proof is blocked because no valid caller call attempt can be created and Exotel callback secret is missing.

## 8. Site Visit Proof Result

Result: CODE HARDENED, LIVE TEST BLOCKED.

Site visit functions now enforce assignment, org match, POST-only methods, one-way proof transitions, GPS state, and proof path hygiene. Live proof is blocked until caller and project test config are available.

## 9. Broker Lock Result

Result: CODE HARDENED, LIVE TEST BLOCKED.

Broker lock creation now blocks conflicting active locks and only updates lead brokerage state after lock creation succeeds. Live lock proof is blocked until site visit proof completes.

## 10. Remaining Risks

1. Invalid caller credentials stop the trust loop before assignment and secure call.
2. Missing provider secrets stop live secure-call proof.
3. Missing callback secret means real provider callbacks will fail closed.
4. Missing caller invite secret blocks new caller onboarding.
5. Site visit and broker lock proof still need a full live run.
6. Broker A/B isolation needs a second broker test identity.
7. `supabase/config.toml` was not pushed with `config push` because local auth URLs are localhost and unsafe for production config push.
8. Existing historical UAT data remains in remote unless explicitly cleaned with a safe, audited process.

## 11. Final Verdict

B. PARTIAL - PROVIDER/CONFIG BLOCKERS REMAIN

Do not mark this controlled trust-loop pilot ready yet. The foundation is stronger, but the complete loop is not proven end to end.
