# RLS SECURITY AUDIT

Generated: 2026-05-22
Verdict: C. BLOCKED - SECURITY / LOGIC FAILURE FOUND

## What was tested
- RLS migrations, reporting views, broker isolation helpers, anonymous/sensitive table behavior from UAT, and service-role bypass surfaces.

## What passed
- UAT verified broker anon client could not read `leads_sensitive`.
- Secure reporting views were previously hardened with `security_invoker`.
- Core sensitive contact encryption/decryption is restricted to server-side routines in the audited trust-loop path.

## What failed
- `supabase/migrations/001_create_crm_erp_schema.sql:104-126` creates broad authenticated policies using `USING (true)` and `WITH CHECK (true)` for `leads`, `visited_leads`, and `lead_history`.
- The same migration destructively drops those tables at `supabase/migrations/001_create_crm_erp_schema.sql:5-7`.
- Service-role Next APIs bypass RLS entirely through `web-dashboard/src/lib/server-supabase.ts:3-11`.
- Read-all policies remain for projects and inventory at `supabase/migrations/20240504000100_sprint2_verification.sql:89` and `supabase/migrations/20260509000100_phase3_inventory_erp.sql:41-42`.

## What is dangerous
- A deployed CRM route can read or mutate legacy lead tables through service-role even when database RLS is correct.
- Authenticated-wide policies are not organization isolation. In this domain, cross-org lead visibility is a trust failure.
- The migration dry run failed, so the effective remote RLS state is not proven to match the local repo.

## What is unproven
- Broker isolation across both `linked_user_id` and `owner_user_id` identity models.
- Developer role restrictions in the new Next dashboard routes.
- Whether broad project/inventory reads are intentional public catalog behavior or tenant leakage.

## Exact blocker
- `web-dashboard/src/app/api/crm-erp/leads/search/route.ts:20-24` reads `leads` with a service-role client and no visible route auth.
- `web-dashboard/src/app/api/crm-erp/leads/batch-update/route.ts:14-37` performs bulk lead updates and history inserts with service-role and no visible route auth.

## Exact recommended fix
- Remove service-role from request-facing Next handlers.
- Require JWT/session validation, map user to `pilot_users`/`role_assignments`, and apply org-scoped filters on every query.
- Replace `USING (true)` policies with org/role-scoped predicates.
- Resolve migration drift and rerun release gate before pilot.

## Harsh-truth verdict
RLS is hardened in parts of the Supabase trust loop, but the system is blocked because service-role API surfaces and broad legacy policies can bypass the isolation model.

