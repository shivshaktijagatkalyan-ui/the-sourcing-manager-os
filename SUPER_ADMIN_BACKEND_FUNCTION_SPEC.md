# Super Admin Backend Function Spec

## Verdict

Final verdict: B. PARTIAL - DASHBOARD BUILT BUT RELEASE GATE / PERMISSION UAT BLOCKED.

The Edge Function is implemented and statically verified. It still needs deployed Supabase UAT to prove real role rejection, platform admin acceptance, and audit persistence in the target environment.

## Function

Path:

`supabase/functions/super-admin-dashboard/index.ts`

Purpose:

Return one safe typed Super Admin dashboard snapshot for the Flutter command center.

## Request Flow

1. Accept `GET` or `POST`; return stable `invalid_method` for other methods.
2. Resolve the current user from JWT.
3. Reject anonymous requests with `unauthorized`.
4. Check active `role_assignments` for `platform_admin` or `ops_admin`.
5. Check active organization.
6. Check active `pilot_users` row in the organization.
7. Compute `allowed_actions`.
8. Require `view_super_admin_dashboard`.
9. Read safe metadata and aggregate counts.
10. Build the dashboard snapshot.
11. Insert `audit_events` row with `super_admin_dashboard_viewed`.
12. Return `ok: true` with snapshot fields.

## Helper Functions

Implemented helpers:

- `requirePlatformAdmin()`
- `allowedPermission()`
- `getAllowedActions()`
- `getPlatformHealthSnapshot()`
- `getOrganizationSummary()`
- `getProjectSummary()`
- `getWorkforcePerformance()`
- `getAttentionQueue()`
- `getWorkflowBottlenecks()`
- `getWorkflowSummary()`
- `getTrustOperations()`
- `getRiskSummary()`
- `getAuditTimeline()`
- `recordAudit()`

The shared `requirePermission()` helper remains the central permission primitive.

## Snapshot Fields

The response includes:

- `generated_at`
- `platform_health`
- legacy-compatible `health`
- `kpis`
- `attention_queue`
- `workforce`
- `organizations`
- `projects`
- `workflow_summary`
- `workflow_bottlenecks`
- `trust_operations`
- `risk_alerts`
- `audit_events`
- `allowed_actions`

## Safe Data

The function queries safe/public and operational metadata tables:

- `organizations`
- `pilot_users`
- `role_assignments`
- `role_permissions`
- `projects`
- `brokers_public`
- `leads_public`
- `data_loans`
- `call_attempts`
- `site_visits`
- `broker_locks`
- `audit_events`
- `abuse_events`
- `risk_notifications`
- `system_health_events`
- `edge_function_failures`
- `broker_followups`
- `payout_ledger`
- `provider_failures`
- `deployment_events`
- `broker_activations`
- `disputes`

The function must not return sensitive customer records, direct contact data, broker private data, provider secrets, raw notes, or service keys.

## Gated Actions

The function does not perform mutating Super Admin actions. It only returns allowed action tokens. Mutations must go through protected workflow functions such as:

- `create-organization`
- `pause-organization`
- `resume-organization`
- `invite-user`
- `assign-role`
- `activate-user`
- `deactivate-user`
- `suspend-user`
- `update-permission-template`
- `incident-response`
- `acknowledge-risk-notification`
- `resolve-abuse-event`
- `data-loan-workflow`
- `manage-caller-workflow`
- `broker-vault-workflow`

## Permissions

The function maps active role and permission data into action tokens:

- dashboard visibility
- platform health
- risk dashboard
- diagnostics
- workforce reports
- organization management
- invite/assign users
- pause/resume organization
- suspend users
- audit events
- broker locks/payouts
- data loans
- site visit reviews
- developer projects

## Workflow Bottlenecks

Detected bottlenecks include:

- unassigned leads
- leads without broker attribution
- expired data loans needing review
- overdue broker followups
- scheduled visits not started
- GPS/proof gaps
- callback failures

Each bottleneck returns severity, type, title, safe reference, action, route, metrics, and timestamp.

## Verification Status

Passed locally:

- security scans
- static Sprint 7 check
- TypeScript command
- Flutter dashboard tests
- Flutter analyze
- Flutter web release build
- Flutter APK release build
- Super Admin static contract check

Blocked:

- release gate trust-loop UAT due local Supabase auth endpoint refusal
- migration dry-run ordering review
- live platform-admin/non-admin permission UAT
- live audit event persistence confirmation

