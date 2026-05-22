# SITE VISIT PROOF UAT REPORT

Date: 2026-05-12

## Result

CODE HARDENED, LIVE UAT BLOCKED.

## Changed

- `create-site-visit`
  - Requires POST.
  - Validates UUID inputs.
  - Writes `organization_id` into `site_visits`.
- `start-site-visit`
  - Requires assigned sourcing manager.
  - Requires org match.
  - Requires `can_verify_site_visits`.
  - Only transitions `scheduled` to `started`.
- `verify-site-gps`
  - Requires POST.
  - Validates UUID/numeric GPS inputs.
  - Requires assigned sourcing manager.
  - Requires visit status `started`.
  - Wrong GPS fails closed.
- `upload-site-photo`
  - Requires POST.
  - Validates UUID.
  - Requires org match and status `gps_verified`.
- `verify-site-visit-proof`
  - Adds one-way proof state gates.
  - Rejects invalid proof state transitions.
  - Rejects proof storage paths containing likely contact-number tokens.
  - Creates broker lock only after proof sequence reaches `visit_done`.

## Blocked

Live site-visit UAT did not run because the trust-loop UAT stopped at caller sign-in. The script also requires:

- `TRUST_LOOP_PROJECT_ID`
- `TRUST_LOOP_PROJECT_LAT`
- `TRUST_LOOP_PROJECT_LNG`

## Verdict

The site-visit proof code is stricter, but proof has not passed live UAT.
