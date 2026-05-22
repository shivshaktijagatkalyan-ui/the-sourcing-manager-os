# Super Admin Dashboard Operation Flow Report

Date: 2026-05-21

## Verdict

The Flutter Super Admin dashboard is implemented as a production-safe control room for reading, routing, governing, and auditing platform operations. It does not directly manage data by writing tables from the dashboard. It manages the wider dashboard ecosystem by:

- resolving the logged-in role into the correct dashboard,
- loading one typed, metadata-only Supabase Edge Function snapshot,
- rendering platform health, workforce, organization, project, risk, trust, and workflow sections,
- exposing only permission-gated quick actions and route buttons,
- pushing operators into existing protected operational screens where mutations stay behind dedicated Edge Functions.

The super-admin operation flow is connected end-to-end. The separate Next.js lead optimization components are present, but the optimized virtual lead grid and smart search components are not fully connected to the broker dashboard yet.

## Files Checked

- `flutter_app/lib/screens/role_dashboard_container.dart`
- `flutter_app/lib/utils/role_resolver.dart`
- `flutter_app/lib/main.dart`
- `flutter_app/lib/screens/super_admin_dashboard.dart`
- `flutter_app/lib/models/super_admin_dashboard_snapshot.dart`
- `flutter_app/lib/services/super_admin_dashboard_service.dart`
- `flutter_app/lib/widgets/super_admin/*.dart`
- `supabase/functions/super-admin-dashboard/index.ts`
- `supabase/config.toml`
- `scripts/super-admin-dashboard-static-check.mjs`
- `flutter_app/test/super_admin_dashboard_strategy_test.dart`
- `web-dashboard/src/components/VirtualLeadGrid.tsx`
- `web-dashboard/src/components/LeadSearch.tsx`
- `web-dashboard/src/components/BrokerDashboardFutureTrust.tsx`
- `web-dashboard/src/app/broker/page.tsx`

## Role And Dashboard Management

Dashboard entry starts in `RoleResolver.currentRole()`. In production, it checks `role_assignments` first, then falls back to `pilot_users`. In training or unconfigured local mode, it uses `mockRole` and query-parameter role overrides.

`RoleDashboardContainer` routes:

| Role | Dashboard |
| --- | --- |
| `caller` | `CallerDashboardScreen` |
| `broker`, `broker_owner`, `broker_agent` | `BrokerDashboardScreen` |
| `sourcing_manager` | `SourcingManagerDashboard` |
| `developer_admin`, `platform_admin`, `admin` | `SuperAdminDashboard` |
| `anonymous` | `LoginScreen` |
| unknown / unsupported | `AccessRestrictedScreen` |

Inside `MainNavigation`, the side drawer shows role-specific menus. For admin roles, it exposes admin navigation entries for organizations, projects, users and roles, brokers, lead overview, site visits, risk, audit, health, and diagnostics. This is navigation-level access only. Backend functions and individual screens still need to enforce permissions.

## Super Admin Frontend Flow

`SuperAdminDashboard` loads data through a single state path:

1. `_loadDashboard()` checks environment mode.
2. Production mode calls `_loadLive()`.
3. `_loadLive()` calls `SuperAdminDashboardService().loadSnapshot()`.
4. The service invokes the Supabase Function named `super-admin-dashboard`.
5. Response JSON is parsed into `SuperAdminDashboardSnapshot`.
6. Widgets render only typed snapshot fields.

The screen does not call Supabase `.from()`, `.rpc()`, or `.functions.invoke()` directly. That keeps the dashboard from becoming a broad table client.

Rendered sections:

- platform health,
- KPI grid,
- permission-gated quick actions,
- attention queue,
- workflow bottlenecks,
- workflow summary,
- workforce performance,
- organizations,
- projects,
- trust operations,
- risk alerts,
- audit timeline.

Training mode uses `buildDemoSuperAdminSnapshot()`, which keeps local demos typed and isolated from Supabase.

## Super Admin Backend Flow

The Edge Function is registered in `supabase/config.toml` with `verify_jwt = true`.

Backend request flow:

1. Accepts `GET` or `POST`; rejects other methods.
2. Resolves actor from JWT with `currentUser(req)`.
3. Uses service-role access only inside the Edge Function.
4. Requires `platform_admin` or `ops_admin` in active `role_assignments`.
5. Requires active organization status.
6. Requires active `pilot_users` membership for that organization.
7. Computes `allowed_actions` from `requirePermission()` and `role_permissions`.
8. Reads only selected safe metadata and aggregate counts.
9. Records `super_admin_dashboard_viewed` in `audit_events`.
10. Returns one deterministic JSON snapshot.

Main backend snapshot builders:

| Helper | Purpose |
| --- | --- |
| `getPlatformHealthSnapshot` | function failures, provider failures, callbacks, release/security/migration status |
| `getOrganizationSummary` | organization list with active users, project counts, risk counts |
| `getProjectSummary` | project metadata plus active leads, verified visits, active brokers |
| `getWorkforcePerformance` | broker, caller, and sourcing-manager aggregate performance |
| `getAttentionQueue` | risk, dispute, failed callback, held sync review queue |
| `getWorkflowBottlenecks` | operational blockers such as unassigned leads and proof gaps |
| `getWorkflowSummary` | daily lead, call, visit, proof, lock, and payout counters |
| `getTrustOperations` | broker locks, disputes, expiring locks, proofs, payouts |
| `getRiskSummary` | risk notifications and abuse events |
| `getAuditTimeline` | safe event type, actor role, organization reference, timestamp |

## Safe Data Boundary

The dashboard snapshot is metadata-only. It uses selected columns, count queries, safe references, and `cleanText()` redaction. The model also redacts phone-like and email-like strings before searchable or rendered output.

Allowed examples:

- counts,
- statuses,
- project and organization safe names,
- role labels,
- safe refs like `risk:abc12345`, `flow:stuck_lead`, `trust:broker_lock`,
- reason codes,
- route tokens,
- action tokens.

Forbidden examples:

- phone numbers,
- email lists,
- raw buyer names,
- raw provider payloads,
- encrypted contact blobs,
- raw audit context blobs,
- service role keys or provider secrets.

## Permission-Gated Action Flow

The dashboard does not perform mutations directly. It receives `allowed_actions` from the Edge Function, then the frontend uses those tokens to decide which buttons and route chevrons are visible.

Quick actions route to existing protected modules:

| Action Surface | Permission Tokens | Destination |
| --- | --- | --- |
| Create Organization | `manage_organizations`, `can_manage_org_users` | `OrganizationOnboardingWizard` |
| Invite User | `invite_users`, `can_manage_org_users` | `InviteUserScreen` |
| Assign Role | `assign_roles`, `can_manage_org_users` | `RoleManagementScreen` |
| Open Risk Dashboard | `view_risk_dashboard`, `can_view_risk_dashboard` | `AbuseMonitoringDashboard` |
| Open Diagnostics | `view_diagnostics` | `AdminDiagnosticsScreen` |
| Open Assignment Queue | `open_assignment_queue`, `view_workforce_reports` | `CallerLeadQueueScreen` |
| Open Broker Locks | `view_broker_locks`, `can_view_payouts` | `PayoutLedgerScreen` |
| Open System Health | `view_system_health` | `SystemHealthDashboard` |
| Open Visit Reviews | `can_review_site_visits`, `broker_reviews` | `BrokerReviewListScreen` |

Attention and operational rows follow the same route model:

```text
backend row: { type, severity, safe_ref, action, route, metrics }
        -> typed Dart model
        -> row widget
        -> _destinationFor(route, action, allowed_actions)
        -> existing protected operational screen
        -> dedicated Edge Function handles any mutation
```

This preserves deterministic sales and trust flow. The dashboard acts as a command router, not a generic AI controller or direct database editor.

## Optimization Operation Flow

For Super Admin, the optimization flow is already represented by `workflow_bottlenecks`, `workflow_summary`, `trust_operations`, `risk_alerts`, and `attention_queue`.

The backend detects operational gaps:

- leads without caller assignment,
- leads without broker attribution,
- expired data loans,
- overdue broker follow-ups,
- scheduled visits not started,
- GPS proof gaps,
- photo proof gaps,
- provider callback failures,
- disputed or expiring broker locks,
- pending payout eligibility,
- risk notifications and abuse events.

Each detected gap becomes a deterministic row with:

- severity,
- title,
- safe reference,
- action token,
- route token,
- count metrics,
- timestamp.

The frontend renders those rows through `WorkflowBottleneckCard`, `TrustOperationsCard`, `RiskAlertCard`, and `AttentionQueueCard`. Tapping a row routes the operator to the appropriate module only when `allowed_actions` authorizes it.

## Next.js Lead Optimization Status

The Next.js dashboard has optimization components:

- `VirtualLeadGrid.tsx` implements virtual scrolling for visible lead cards.
- `LeadSearch.tsx` implements `LeadSearchBar`, `SmartFilterBar`, `BulkActionBar`, and `LeadLoadingOptimization`.
- `LEAD_MANAGEMENT_OPTIMIZATION.md` describes the intended performance flow.

Current connection status:

- `web-dashboard/src/app/broker/page.tsx` renders only the `LeadLoadingOptimization` guide component above `BrokerDashboardFutureTrust`.
- `BrokerDashboardFutureTrust.tsx` still uses local `filteredLeads`, `displayedLeads = filteredLeads.slice(0, visibleLeadCount)`, manual card mapping, and a load-more pattern.
- `VirtualLeadGrid`, `LeadSearchBar`, `SmartFilterBar`, and `BulkActionBar` are not wired into `BrokerDashboardFutureTrust`.

So the optimization UI is partially created, but not fully connected in the Next.js broker dashboard.

## Recommended Connection Pattern

For Super Admin:

1. Keep `super-admin-dashboard` as the only dashboard read endpoint.
2. Add any new optimization operation as a new safe row type in the Edge Function, not as direct frontend table queries.
3. Reuse the existing row contract: `id`, `type`, `severity`, `title`, `safe_ref`, `action`, `route`, `metrics`, `created_at`.
4. Parse through `SuperAdminDashboardSnapshot`.
5. Render through an existing card or a new card that accepts typed `AdminOperationalRow`.
6. Route through `_destinationFor(route, action, allowedActions)`.
7. Put any mutation in a dedicated protected Edge Function.
8. Add a static check and Flutter widget/model test for the new row type.

For the Next.js broker optimization:

1. Import `VirtualLeadGrid`, `LeadSearchBar`, `SmartFilterBar`, and `BulkActionBar` into `BrokerDashboardFutureTrust`.
2. Replace `displayedLeads.map(...)` and the load-more button with `VirtualLeadGrid`.
3. Connect search state to `LeadSearchBar` and filter state to `SmartFilterBar`.
4. Keep bulk actions deterministic and call protected APIs or Edge Functions for production mutations.
5. Do not put phone numbers or contact export links into optimized rows.

## Gaps And Risks

1. `developer_admin` is routed to `SuperAdminDashboard` by Flutter role routing, but the backend `super-admin-dashboard` accepts only `platform_admin` or `ops_admin`. If this is intentional, the dashboard will show a deterministic restricted state for developer admins. If developer admins should see a narrower dashboard, backend role logic needs a separate scope.

2. The admin drawer exposes several admin screens based on broad admin role classification. The dashboard quick action panel is permission-gated, but drawer navigation is less granular. Production safety depends on each destination screen and Edge Function enforcing its own permission checks.

3. The Next.js optimization report overstates connection status. The virtual scrolling and smart search components exist, but the main broker dashboard still uses the older displayed-list pattern.

4. The Super Admin dashboard currently routes to existing modules. Some route targets are broad fallback modules, such as diagnostics or payout ledger, rather than dedicated review screens for every bottleneck type.

## Final Assessment

The Super Admin dashboard is production-safe as a read-only control room and operation router. The core FE-to-backend connection is sound:

```text
role resolver
  -> role dashboard container
  -> SuperAdminDashboard
  -> SuperAdminDashboardService
  -> super-admin-dashboard Edge Function
  -> typed safe snapshot
  -> permission-gated widgets and route actions
  -> protected operational modules
```

The optimization operation flow for Super Admin is connected through deterministic backend snapshot rows. The Next.js lead performance optimization layer is only partially connected and should be wired before claiming it is active in the broker dashboard.
