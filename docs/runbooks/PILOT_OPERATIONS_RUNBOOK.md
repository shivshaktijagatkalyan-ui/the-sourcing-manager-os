# Pilot Operations Runbook (v1.0.0)

This is the mandatory line-by-line execution guide for the Sourcing Manager OS Operators. Each step must be evidenced by a log, hash, or screenshot.

**Test Credentials**: Reference [TEST_CREDENTIALS.md](file:///c:/Users/iBUGG3D/Desktop/The%20Sourcing%20MAnager%20OS/TEST_CREDENTIALS.md) for pilot login details.

## 🟢 Gate 1: Environment & Secret Hardening

| Step | Action | Evidence Required |
| :--- | :--- | :--- |
| 1.1 | Verify `PHONE_ENCRYPTION_KEY` is not in source control. | Hash of the key (stored in Supabase Secrets). |
| 1.2 | Set Exotel Production SID/API Key. | `exotel-callback` smoke test log. |
| 1.3 | Verify `site_visit_photos` bucket is private (No Public URLs). | Curl attempt to a direct object URL returns 403. |
| 1.4 | Verify `statement_reports` bucket is private. | Curl attempt returns 403. |

## 🛡️ Gate 2: Security & Constitution Verification

| Step | Action | Evidence Required |
| :--- | :--- | :--- |
| 2.1 | Run `python scripts/security-check.py`. | Console output: "0 Vulnerabilities Found". |
| 2.2 | Run `grep -r "phone" flutter_app/lib`. | Console output: (Only variable names, no hardcoded numbers). |
| 2.3 | Test Edge Function `check-rate-limit` manually. | 429 Error log in `system_health_events` after 5 calls. |
| 2.4 | Attempt direct SQL write to `leads_private` as `anon`. | Result: "Permission Denied" (RLS Evidence). |

## 🚢 Gate 3: Deployment Evidence

| Step | Action | Evidence Required |
| :--- | :--- | :--- |
| 3.1 | Apply Migrations: `20240501...` to `20240511...`. | ✅ **COMPLETE**: All 35 migrations applied (last: `20260507000600` on May 7, 2026 10:41 UTC). Output: `supabase migration list` confirms sync. |
| 3.2 | Deploy 30+ Edge Functions. | `supabase functions deploy --all` success log. |
| 3.3 | Record Flutter Build Hash. | Git Commit SHA + Flutter build timestamp. |

## 🧪 Gate 4: The "Full-Flow" Smoke Test

*Mandatory: Perform this flow with one Broker, one Manager, and one Caller.*

| Step | Action | Success Marker |
| :--- | :--- | :--- |
| 4.1 | **Invite**: Manager invites Broker. | ✅ **COMPLETE**: Verified via `onboarding_audit_events` for user `antigravity.test@gmail.com`. |
| 4.2 | **Accept**: Broker accepts and activates. | ✅ **COMPLETE**: `user_profiles.status` = `active` for Jitu Gupta. |
| 4.3 | **Source**: Broker uploads a lead. | `leads_public` entry exists; PII is encrypted in `leads_private`. |
| 4.4 | **Loan**: Manager grants Data Loan. | `data_loans` entry exists with correct expiry. |
| 4.5 | **Call**: Caller initiates bridge call. | Exotel log shows `Status: 200` (Verify no number visible to Caller). |
| 4.6 | **Visit**: Field agent verifies GPS inside geofence. | `site_visits.status` = `verified`. |
| 4.7 | **Lock**: 45-Day Commission Lock created. | `payout_ledger` shows `status: locked` + `maturity_date`. |

## 🔄 Gate 5: Incident & Rollback Drills

| Step | Action | Evidence Required |
| :--- | :--- | :--- |
| 5.1 | **Incident**: Call `pause-organization`. | Verify all Org user sessions return 403 instantly. |
| 5.2 | **Rollback**: Revert to previous Edge Function version. | Function dashboard shows successful redeploy of previous SHA. |
| 5.3 | **Recovery**: Resume organization. | Verify sessions are restored. |

## ⚖️ Gate 6: Legal & Compliance Sign-off

| Step | Action | Sign-off Required |
| :--- | :--- | :--- |
| 6.1 | Legal Review of `PRIVACY_POLICY.md`. | [ ] (Sign-off Initials) |
| 6.2 | Legal Review of `TERMS_OF_USE.md`. | [ ] (Sign-off Initials) |
| 6.3 | AGPL Public Repository Notice verified. | [ ] (Sign-off Initials) |

---
**Status: ALL GATES PENDING EVIDENCE.**
**Operator Signature: ____________________**
