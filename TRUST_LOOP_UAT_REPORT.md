# TRUST LOOP UAT REPORT

Generated: 2026-05-23T07:27:43.035Z

| Step | Status | Detail | Evidence |
| --- | --- | --- | --- |
| function config drift | PASS | local function directories match supabase/config.toml |  |
| local provider config | PASS | Local Exotel provider keys are present for signature verification |  |
| broker sign-in | PASS | authenticated with anon client only | 49157d39-5b1b-450e-8807-fa5eeb93a3aa |
| broker onboarding | PASS | server-governed complete-onboarding accepted broker |  |
| broker lead upload | PASS | lead created without returning contact data | 18ac60fb-d310-4cf0-8140-dd358d7238de |
| AI tool: trust-get-lead-summary | PASS | tool returned metadata-only response safely |  |
| AI tool: trust-get-broker-lock-status | PASS | tool returned metadata-only response safely |  |
| AI tool: trust-get-followup-risk | PASS | tool returned metadata-only response safely |  |
| AI tool: trust-recommend-next-action | PASS | tool returned metadata-only response safely |  |
| AI tool: trust-create-followup | PASS | tool created followup and scrubbed reason safely |  |
| sensitive table frontend access | PASS | broker anon client cannot read leads_sensitive rows |  |
| duplicate prevention | PASS | same contact was blocked as duplicate without exposing the contact |  |
| sourcing manager sign-in | PASS | authenticated with anon client only | 9e693533-ad98-455f-9d87-70e9c1e20d22 |
| sourcing manager visibility | PASS | assigned sourcing manager can see public lead metadata only |  |
| caller sign-in | PASS | authenticated with anon client only | 1f035fd1-fded-498b-bafc-b60ffa9723e8 |
| caller assignment and data loan | PASS | SM assigned caller and active call data loan was created |  |
| secure call initiation | PASS | provider accepted call request without contact exposure |  |
| fake provider callback | PASS | forged callback could not mark call successful |  |
| call outcome and follow-up | PASS | caller outcome update accepted without contact exposure |  |
| site visit scheduling | PASS | site visit created through Edge Function | 562fd47e-4118-4b9d-b201-8085b51a7f50 |
| wrong GPS rejection | PASS | bad GPS failed closed and invalidated visit |  |
| site visit start | PASS | assigned SM started scheduled visit |  |
| valid GPS verification | PASS | valid GPS proof passed at 0m |  |
| photo proof | PASS | photo proof metadata accepted without contact data |  |
| broker lock creation | PASS | site visit completed and broker lock created/extended |  |
| final lead state | PASS | lead status updated to visit_verified and brokerage locked |  |
| AI tool: trust-get-site-visit-proof | PASS | tool returned verified proof metadata safely |  |
| audit trail review | PASS | audit response contained 14 PII-safe events |  |

## Result

PASS - complete controlled trust loop passed.
