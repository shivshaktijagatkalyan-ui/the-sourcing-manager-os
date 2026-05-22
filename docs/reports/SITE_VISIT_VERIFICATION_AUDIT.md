# SITE VISIT VERIFICATION AUDIT

Generated: 2026-05-22
Verdict: C. BLOCKED - SECURITY / LOGIC FAILURE FOUND

## What was tested
- Site visit creation, GPS verification, wrong-GPS rejection, photo proof metadata acceptance, visit completion, and proof retrieval.

## What passed
- Wrong GPS was rejected in UAT.
- Valid GPS was accepted in UAT.
- Release-gate UAT completed photo proof and broker lock on one generated run.
- `verify-site-visit-proof` enforces state order through `allowedProofStates` at `supabase/functions/verify-site-visit-proof/index.ts:14-21`.

## What failed
- Standalone UAT failed at photo proof with `invalid_proof_path`.
- `pathContainsRestrictedToken` at `supabase/functions/verify-site-visit-proof/index.ts:28` scans the full storage path. UUID segments can accidentally match `[6-9]\d{9}` and be rejected at `:233-234`.
- `verify-site-visit-proof` accepts `proof_ref_hash` or `photo_storage_path` metadata without proving the storage object exists at `supabase/functions/verify-site-visit-proof/index.ts:229-256`.

## What is dangerous
- Random path false positives can block legitimate visits.
- Metadata-only photo proof can be accepted without a verified storage object in this path.
- GPS verification uses client-supplied latitude/longitude/accuracy; no device attestation or anti-spoofing proof is present in the audited code.

## What is unproven
- Reused proof detection.
- Private bucket policy correctness for `site-evidence`.
- GPS spoof resistance.
- Photo object existence and hash uniqueness in every proof path.

## Exact blocker
- Flaky path validator: `supabase/functions/verify-site-visit-proof/index.ts:28`, `:233-234`.

## Exact recommended fix
- Validate path grammar by expected segments and UUID/hash formats, not by phone regex on the whole path.
- Require proof hash to match an object already uploaded to `site-evidence`.
- Add duplicate proof hash detection per org/project/visit.
- Add device/location risk scoring for GPS submissions.

## Harsh-truth verdict
The site visit workflow is close, but proof acceptance/rejection is not deterministic or strong enough for brokerage-lock trust.

