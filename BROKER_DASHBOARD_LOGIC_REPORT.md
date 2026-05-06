# Broker Dashboard Logic Report

## 1. Role Routing Status

Status: **PASS for local code wiring, deployment required for new DB policy**

- `role_assignments` is now checked first through `RoleResolver`.
- Legacy `pilot_users.role` is retained only as a fallback.
- `sourcing_manager` routes to `SourcingManagerDashboard`.
- `broker_owner`, `broker_agent`, and legacy `broker` route to
  `BrokerDashboardScreen`.
- `caller` routes to `CallerDashboardScreen`.
- `admin`, `platform_admin`, and `developer_admin` route to the developer/admin
  dashboard.
- `anonymous`, `unknown`, or missing role routes to `Access Restricted`.
- Drawer access now fails closed for missing roles instead of exposing sourcing
  or caller menus.

## 2. Broker Dashboard Cards

Status: **IMPLEMENTED**

The broker dashboard now has these safe sections:

- Broker profile header.
- Connected sourcing managers.
- Live projects.
- Leads given.
- Calls attempted on broker-sourced leads.
- Interested leads.
- Site visits scheduled.
- Verified visits.
- Active broker locks.
- Trust score and rank.
- Lead-level data loan status.
- Lead-level progress actions.

The lead action buttons do not mutate protected tables directly. Mutating loan
actions are intentionally blocked in the UI until an approved Edge Function is
available.

## 3. Data Sources

Status: **WIRED IN CODE**

Live dashboard data is sourced from:

- `brokers_public` filtered by `linked_user_id = auth.uid()`.
- `broker_activations` filtered by broker ids visible to the logged-in broker.
- `projects` through broker activations.
- `leads_public` filtered by `source_broker_id`.
- `data_loans` filtered by broker-sourced lead ids.
- `call_attempts` filtered by broker-sourced lead ids.
- `site_visits` filtered by `source_broker_id`.
- `broker_locks` filtered through linked source site visits.

New migration:

- `20240518000000_broker_dashboard_access.sql`

This migration adds the missing broker-auth mapping:

- `brokers_public.linked_user_id`

It also adds RLS policies that let a broker read only their own safe dashboard
rows through this mapping. No sensitive table read policy was added.

The `linked_user_id` field is protected by a trigger. It can only be changed by
an actor with `can_manage_org_users`, and the change writes a sanitized
`broker_user_link_updated` audit event.

## 4. Backend Wiring Fixes

Status: **PATCHED LOCALLY**

`lead-from-broker` had two practical MVP insert bugs:

- It inserted `lead_alias`, but the existing lead table uses `alias`.
- It inserted external `brokers_public.id` into `leads_public.broker_id`, but
  that column references `auth.users(id)`.

Fix applied:

- Store public lead alias in `leads_public.alias`.
- Store the authenticated actor in `leads_public.broker_id`.
- Store Vinod/source manager in `leads_public.assigned_manager_id`.
- Keep external broker attribution in `leads_public.source_broker_id`.
- Clamp lead status to existing valid states, defaulting to `new`.

## 5. Security Checks

Status: **PASS for local static checks**

Expected guarantees from code inspection:

- No customer contact value is displayed.
- No masked or partial customer contact value is displayed.
- No browser direct-call link is generated.
- No export action is added.
- No sensitive broker/customer table is queried from the dashboard.
- RLS remains required for all live dashboard reads.
- Protected mutations still require Edge Functions.

## 6. Build Result

Status: **PASS for Flutter/security, root TypeScript gate not applicable**

Commands run:

- `python scripts/security-check.py`: PASS.
- `npm run security`: PASS.
- `npm run sprint7:check`: PASS.
- `C:\src\flutter\bin\flutter.bat analyze`: PASS.
- `npm run build`: PASS.
- `npx markdownlint-cli2 BROKER_DASHBOARD_LOGIC_REPORT.md`: PASS.
- `git diff --check`: PASS with CRLF warnings only.
- `npx tsc --noEmit`: FAIL / not applicable. This repo has no root
  TypeScript compiler or root `tsconfig.json`; Edge Functions are Deno/Supabase
  functions.

## 7. Remaining Issues

Status: **MANUAL UAT REQUIRED**

Before Jitu can use this dashboard in production:

1. Deploy `20240518000000_broker_dashboard_access.sql`.
2. Link Jitu's auth user to his broker row:
   `brokers_public.linked_user_id = Jitu auth.uid()`.
3. Confirm Jitu has an active organization, active pilot status, and a broker
   role assignment.
4. Run a browser login test as Jitu and verify only JSN Enterprise rows appear.
5. Run a browser login test as Vinod and verify the sourcing manager dashboard.
6. Confirm live loan action mutations remain blocked until an approved broker
   loan Edge Function exists.

## 8. Verdict

Current status: **PARTIAL - READY FOR DEPLOYMENT AND ROLE UAT**

The app now has the correct role-based dashboard structure and the broker
dashboard has safe public data wiring. It is not yet fully accepted for daily
broker use until the new migration is deployed, Jitu's `linked_user_id` is set,
and live role/browser UAT proves cross-broker isolation.
