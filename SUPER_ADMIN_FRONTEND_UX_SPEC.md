# Super Admin Frontend UX Spec

## Verdict

Final verdict: B. PARTIAL - DASHBOARD BUILT BUT RELEASE GATE / PERMISSION UAT BLOCKED.

The Flutter dashboard has been implemented as a premium dark enterprise control room. It is responsive, permission-aware, and focused on read-only operational status plus protected workflow routing.

## What Was Built

Screen:

- `flutter_app/lib/screens/super_admin_dashboard.dart`

Widgets:

- `PlatformHealthCard`
- `AttentionQueueCard`
- `OrganizationCard`
- `WorkforcePerformanceCard`
- `BrokerPerformanceTable`
- `CallerPerformanceTable`
- `SmPerformanceTable`
- `ProjectHealthCard`
- `AuditTimelineCard`
- `RiskAlertCard`
- `QuickActionPanel`
- `WorkflowBottleneckCard`
- `TrustOperationsCard`

## UI Layout

The page renders:

1. FutureTrust command center header.
2. Platform health card.
3. KPI grid.
4. Quick action panel.
5. Attention queue.
6. Workflow bottlenecks.
7. Workflow summary.
8. Workforce performance tables.
9. Organization control summary.
10. Project health summary.
11. Trust operations and risk alerts.
12. Audit timeline.

## Frontend Connection

The UI depends on `SuperAdminDashboardService`. Production mode calls the Edge Function. Training/unconfigured mode renders `buildDemoSuperAdminSnapshot()` for safe local demonstration.

The dashboard screen does not perform table queries and does not own mutation logic.

## Safe Data

Rendered UI values are normalized and redacted where needed. Unknown or unsafe status/severity strings are displayed as `UNKNOWN`.

The UI displays:

- counts
- status badges
- safe labels
- safe references
- action routes
- role labels
- audit metadata

The UI does not display customer PII, direct contact links, contact exports, or raw sensitive records.

## Gated Actions

Quick actions are hidden when the backend does not include the required action token in `allowed_actions`.

Attention queue rows show navigation affordance only when the route is allowed. Legacy fixtures without explicit route/action fields are mapped by type to the safest matching protected module.

## Permissions

The UI consumes backend action tokens such as:

- `manage_organizations`
- `invite_users`
- `assign_roles`
- `view_risk_dashboard`
- `view_diagnostics`
- `open_assignment_queue`
- `view_broker_locks`
- `view_system_health`
- `view_platform_health`
- `can_review_site_visits`

The UI does not treat these as security enforcement. They are display gates only.

## Routed Workflows

- Risk rows -> Abuse Monitoring Dashboard
- Diagnostics rows -> Admin Diagnostics
- Assignment rows -> Caller Lead Queue
- Broker lock rows -> Payout Ledger
- System health rows -> System Health Dashboard
- Organization actions -> Organization Onboarding
- User actions -> Invite User / Role Management

## Design Rules

- Premium dark command-center style using existing `PremiumUI`.
- Graphite panels, gold/accent emphasis, severity colors for risk.
- No cluttered database-editor layout.
- Mobile/tablet/web responsive through layouts, wraps, and grids.
- Minimal motion through standard Flutter refresh/loading states.

## Remaining Blockers

- Browser/device visual UAT on target screen sizes after deployment.
- Live permission UAT to verify hidden buttons match backend permissions for real users.
- Product review of exact labels for operations team vocabulary.

