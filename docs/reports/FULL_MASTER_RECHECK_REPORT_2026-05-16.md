# FULL MASTER RECHECK REPORT

Generated: 2026-05-16
Project: FutureTrust Real Estate OS / The Sourcing Manager OS
Mode: Harsh-truth full repo verification

## Final Verdict

B. PARTIAL - PROVIDER/CONFIG BLOCKERS REMAIN

Do not mark Verdict A. The full release gate still exits 1.

## Critical Findings

1. The full release gate fails at Trust Loop UAT because the live provider path is not complete.
2. Provider configuration is still blocked.
3. Secure-call UAT stops at `consent_required`, so provider handoff is not reached.
4. A valid live provider callback success path is still not proven.
5. A pending AI churn migration exists and should not be pushed into a controlled trust pilot without separate approval and threat modeling.
6. New AI voice endpoints were found unsafe and were disabled fail-closed during this recheck.

## Post-Claim Recheck

A later claim said the AI voice functions had been rebuilt as secure provider bridges and the UAT consent block had been resolved through a service-role fixture.

That claim was rejected after file inspection.

Findings:

- `ai-voice-churn` could dispatch explicit lead IDs without rechecking consent/DND per lead.
- AI callbacks did not enforce enough attempt/provider/state/replay validation to be trusted as workflow authority.
- AI summaries were still being written into call metadata and audit context.
- `ai-lead-response` sent identity-like lead data to the voice provider.
- `scripts/uat-trust-loop.mjs` directly mutated `consent_status` and `dnd_status` with `SUPABASE_SERVICE_ROLE_KEY`, which is simulation evidence, not release evidence.

Correction applied:

- `ai-lead-response`, `ai-voice-churn`, and `ai-voice-callback` are fail-closed again.
- The service-role consent mutation was removed from release UAT.
- Fresh security, type, drift, lint, web build, Flutter build, and release-gate checks were rerun.

Fresh release gate still exits 1.

## Commands Run

| Command | Result |
| --- | --- |
| `python scripts/security-check.py` | PASS |
| `npm run security` | PASS |
| `npm run sprint7:check` | PASS |
| `node scripts/ai-safe-tool-check.mjs` | PASS |
| `node scripts/check-function-drift.mjs` | PASS - 55 functions |
| `npx tsc --noEmit` | PASS |
| `npm run build` | PASS |
| `flutter test` | PASS - 23 tests |
| `npm --prefix web-dashboard run lint` | PASS |
| `npm --prefix web-dashboard run build` | PASS |
| `powershell -ExecutionPolicy Bypass -File scripts\release-gate.ps1` | FAIL - exit 1 |

## Release Gate Result

The release gate passed:

- security constitution scan,
- root TypeScript check,
- function/config drift check,
- Supabase migration dry run,
- Flutter analyze,
- Flutter web release build,
- Flutter APK release build.

The release gate failed:

- Trust Loop UAT.

Reason:

- `provider config` is BLOCKED.
- `provider call section` is BLOCKED.
- The provider was not reached because the call stopped at `consent_required`.

## Trust Loop UAT Evidence

Fresh report: `TRUST_LOOP_UAT_REPORT.md`

Strong passes:

- broker sign-in,
- broker onboarding,
- broker lead upload,
- AI-safe metadata tools,
- sensitive table frontend access denied,
- duplicate prevention,
- sourcing manager visibility,
- caller sign-in,
- caller assignment and data loan,
- secure-call fail-closed behavior,
- forged callback rejection,
- outcome/follow-up,
- site visit scheduling,
- invalid GPS rejection,
- valid GPS proof,
- photo proof,
- broker lock creation,
- final lead state update,
- PII-safe audit review.

Still blocked:

- live provider handoff,
- valid live callback success path.

## AI Voice Hardening Applied

The following endpoints were unsafe for the current trust pilot model and were changed to fail closed:

- `supabase/functions/ai-lead-response/index.ts`
- `supabase/functions/ai-voice-churn/index.ts`
- `supabase/functions/ai-voice-callback/index.ts`

Reason:

- AI voice must not bypass the secure-call trust loop.
- AI must not receive raw identity as an unrestricted automation path.
- Provider callbacks must not update lead state without strong verification.
- Summaries/transcripts must not enter public workflow or audit paths without a PII scrubber and retention policy.

## Web Dashboard Hygiene Applied

Runtime frontend logging was removed from:

- `web-dashboard/src/lib/supabase.ts`
- `web-dashboard/src/components/BrokerDashboardFutureTrust.tsx`
- `web-dashboard/src/app/page.tsx`
- `web-dashboard/src/app/auth/callback/page.tsx`

The broad scan found no remaining matches for:

- `console.log`,
- `console.error`,
- `tel:`,
- `wa.me`,
- `api.whatsapp.com`,
- `masked_phone`,
- `last_four`,
- direct frontend sensitive table reads,
- frontend service-role key usage.

## Pending Migration Risk

`supabase/migrations/20260516000100_ai_data_churn_engine.sql` is pending in the dry run.

Risk:

- It introduces AI churn workflow states and campaign tables before AI voice is production-governed.
- It is not required to prove the protected broker trust loop.
- It should not be pushed as part of a controlled trust-loop pilot unless deliberately approved.

## Operational Readiness

Ready:

- internal trust-loop logic,
- broker onboarding,
- encrypted lead upload,
- role-based metadata workflow,
- data loan assignment,
- site visit proof,
- broker lock state,
- audit hygiene in exercised paths,
- AI-safe metadata tools.

Not ready:

- live Exotel handoff,
- valid live callback success path,
- consent/DND-ready secure-call UAT,
- AI voice automation,
- unreviewed AI churn schema rollout.

## Final Rule

No Verdict A until:

- `scripts/release-gate.ps1` exits 0,
- Exotel secrets are configured,
- consent/DND test path reaches provider handoff,
- valid provider callback updates a real attempt,
- no PII leaks,
- broker isolation remains proven,
- AI voice remains disabled or is rebuilt as a governed secure provider bridge.
