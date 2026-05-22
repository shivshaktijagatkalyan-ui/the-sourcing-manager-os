# Super Admin Security And RLS Report

## Verdict

Final verdict: B. PARTIAL - DASHBOARD BUILT BUT RELEASE GATE / PERMISSION UAT BLOCKED.

The implementation follows the dashboard constitution in code: read safe metadata, route to protected modules, gate actions with permissions, and write audit events. Live RLS and role UAT still must be completed against the target Supabase project.

## What Was Built

Security controls implemented in `supabase/functions/super-admin-dashboard/index.ts`:

- JWT user extraction through shared auth helper.
- `requirePlatformAdmin()` role gate for `platform_admin` and `ops_admin`.
- Active `role_assignments` validation.
- Active `pilot_users` validation.
- Active organization validation.
- `getAllowedActions()` permission synthesis.
- Dashboard permission check for `view_super_admin_dashboard`.
- Audit write for `super_admin_dashboard_viewed`.
- Stable public error reason codes.

## Frontend Connection

The frontend never directly queries sensitive or operational tables for this dashboard. It invokes the Edge Function through the service layer and renders the returned snapshot.

This keeps browser-side RLS exposure narrow: the browser receives only the dashboard result, not table clients or raw records.

## Safe Data

Allowed response categories:

- aggregate counts
- status strings
- safe references
- role labels
- workflow labels
- project and organization display metadata
- action tokens

Blocked response categories:

- phone numbers
- masked contact fragments
- WhatsApp or tel links
- customer raw PII
- broker sensitive data
- provider secrets
- service role key
- raw notes
- raw provider payloads

## Gated Actions

The dashboard does not mutate records directly. It routes to existing protected workflows such as:

- organization creation and pause/resume
- user invitation and role assignment
- incident/risk handling
- abuse resolution
- data loan workflow
- caller workflow management
- broker vault workflow
- broker lock and payout review

Every mutation must continue to enforce role, permission, organization, workflow state, and audit writes server-side.

## Permissions

Permission examples supported by the contract:

- `view_super_admin_dashboard`
- `view_platform_health`
- `view_risk_dashboard`
- `view_system_health`
- `view_diagnostics`
- `manage_organizations`
- `invite_users`
- `assign_roles`
- `suspend_users`
- `view_audit_events`
- `manage_incidents`
- `view_workforce_reports`
- `view_broker_locks`
- `manage_data_loans`
- `view_developer_projects`

Legacy role permission tokens are also accepted for compatibility with the current project schema.

## Routed Workflows

The dashboard routes, but does not directly fix:

- assignment gaps
- delayed followups
- proof gaps
- callback failures
- broker lock disputes
- expiring locks
- payout eligibility gaps
- duplicate/risk/abuse events
- platform health issues

## Security Tests Covered Locally

Implemented or statically covered:

- no direct sensitive table query from frontend dashboard source
- no direct frontend table reads from the dashboard screen
- missing permission hides actions
- attention queue navigation is permission gated
- rendered/searchable dashboard text redacts phone-like and email-like values
- anonymous/forbidden/backend error reasons are stable and sanitized
- static scan blocks direct contact links, masked contact display, unsafe logs, and raw internal error returns
- audit write exists in the Edge Function source path

## Remaining Blockers

Live UAT still required:

- anonymous request rejected against deployed function
- broker/caller/sourcing manager rejected against deployed function
- platform admin accepted against deployed function
- action Edge Functions reject missing permissions
- audit event row confirmed after dashboard view and protected action
- RLS policies verified against the current remote schema

Release gate also reported pending migration ordering review before remote application.

