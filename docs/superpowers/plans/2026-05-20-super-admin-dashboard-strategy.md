# Super Admin Dashboard Strategy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a production-safe Super Admin dashboard that reads platform-wide metadata, shows operational health, and routes protected admin actions without exposing lead contact data or bypassing role permissions.

**Architecture:** The Flutter UI should become a read-only command center backed by one metadata-only dashboard Edge Function. Protected mutations stay in existing dedicated Edge Functions such as `create-organization`, `invite-user`, `assign-role`, `pause-organization`, `resume-organization`, and risk/incident functions. The dashboard should show counts, safe lists, reason codes, and drill-down routes, not raw PII or direct table mutation controls.

**Tech Stack:** Flutter, Supabase Auth, Supabase Edge Functions with Deno, Postgres RLS, existing Sprint 7 permission helpers in `supabase/functions/_shared/sprint7.ts`.

---

## Current State

Existing UI:

- `flutter_app/lib/screens/super_admin_dashboard.dart` loads KPIs, organizations, projects, risk alerts, and audit events.
- It falls back to demo data when Supabase is not configured or training mode is enabled.
- It currently performs multiple direct client reads from tables including `organizations`, `projects`, `role_assignments`, `brokers_public`, `leads_public`, `call_attempts`, `site_visits`, `broker_locks`, `disputes`, `abuse_events`, `system_health_events`, and `audit_events`.

Existing backend surfaces:

- `supabase/functions/system-health-check/index.ts` returns metadata-only health status.
- `supabase/functions/generate-diagnostics/index.ts` returns platform diagnostics after JWT and permission checks.
- Sprint 7 role/permission helpers live in `supabase/functions/_shared/sprint7.ts`.

Main risk:

- A super admin dashboard should not depend on broad direct client table access. Even if RLS is correct today, direct multi-table reads are harder to audit and can accidentally reveal cross-org metadata. A single Edge Function can centralize permission checks, safe projections, and audit logging.

---

## Dashboard Purpose

The Super Admin dashboard is a platform control room. It should answer five questions:

1. Is the platform healthy?
2. Which organizations, users, and projects need admin attention?
3. Are there risk, abuse, dispute, or delayed-sync items that need review?
4. Are sales/trust workflows moving correctly across brokers, callers, sourcing managers, and site visits?
5. Which protected admin action should the operator take next?

It should not answer:

- What is the buyer phone number?
- What is the raw provider webhook payload?
- Can I manually mark a lead verified without the trust workflow?
- Can I override a broker lock or payout without a deterministic action endpoint?

---

## Backend Read Strategy

Create one new dashboard read endpoint:

- Create: `supabase/functions/super-admin-dashboard/index.ts`
- Modify: `supabase/config.toml`
- Optional shared helper: `supabase/functions/_shared/admin_dashboard.ts`

Access rules:

- Require JWT.
- Resolve `currentUser(req)`.
- Require `platform_admin` or one of these permissions:
  - `can_manage_org_users`
  - `can_view_risk_dashboard`
  - `can_pause_org`
- Fail closed if the user is suspended, inactive, or mapped to a paused organization.
- Record an audit event `super_admin_dashboard_viewed`.

Read pattern:

- Use service-role Supabase only inside the Edge Function.
- Return only counts, safe names, statuses, IDs, timestamps, and reason codes.
- Never return phone numbers, raw email lists, provider payloads, raw contact text, or encrypted contact blobs.
- Use exact counts with `head: true` for KPIs.
- Limit lists to 5-10 rows per section.
- Sort attention queues by severity and recency.

Response contract:

```json
{
  "ok": true,
  "generated_at": "2026-05-20T18:00:00.000Z",
  "health": {
    "status": "healthy",
    "last_event": "none",
    "critical_failures_1h": 0
  },
  "kpis": {
    "total_organizations": 4,
    "active_projects": 8,
    "active_users": 54,
    "total_brokers": 156,
    "total_leads": 1240,
    "calls_attempted": 832,
    "scheduled_visits": 61,
    "verified_visits": 37,
    "active_locks": 28,
    "open_disputes": 3,
    "open_risk_alerts": 2,
    "held_sync_reviews": 1
  },
  "organizations": [
    {
      "id": "org_uuid",
      "name": "Wadhwa Mumbai",
      "status": "active",
      "active_users": 18,
      "open_risk_alerts": 1,
      "created_at": "2026-05-01T10:00:00.000Z"
    }
  ],
  "projects": [
    {
      "id": "project_uuid",
      "name": "The Wadhwa Wise City",
      "city": "Mumbai",
      "area": "Panvel",
      "status": "active",
      "active_leads": 280,
      "verified_visits": 12
    }
  ],
  "attention_queue": [
    {
      "id": "event_uuid",
      "type": "abuse_event",
      "severity": "critical",
      "title": "Paused org access attempt",
      "reason_code": "paused_org_access_attempt",
      "organization_id": "org_uuid",
      "created_at": "2026-05-20T17:40:00.000Z"
    }
  ],
  "workflow_summary": {
    "lead_intake_today": 24,
    "secure_calls_today": 31,
    "site_visits_today": 7,
    "proofs_pending": 4,
    "locks_created_today": 2,
    "payouts_pending_review": 3
  },
  "audit_events": [
    {
      "id": "audit_uuid",
      "event_type": "organization_created",
      "actor_role": "platform_admin",
      "organization_id": "org_uuid",
      "created_at": "2026-05-20T17:35:00.000Z"
    }
  ],
  "allowed_actions": [
    "create_organization",
    "invite_user",
    "assign_role",
    "pause_organization",
    "resume_organization",
    "view_diagnostics",
    "review_risk"
  ]
}
```

Error contract:

```json
{ "ok": false, "reason": "forbidden_permission_required" }
```

Allowed error reasons:

- `unauthorized`
- `forbidden_permission_required`
- `access_blocked_operational`
- `dashboard_read_failed`
- `internal_server_error`

---

## Backend Action Strategy

Do not put mutation logic inside the dashboard read endpoint.

Use these protected action endpoints:

- Create organization: `supabase/functions/create-organization/index.ts`
- Invite user: `supabase/functions/invite-user/index.ts`
- Accept invite: `supabase/functions/accept-invite/index.ts`
- Assign role: `supabase/functions/assign-role/index.ts`
- Activate/deactivate user: `supabase/functions/activate-user/index.ts`, `supabase/functions/deactivate-user/index.ts`
- Pause/resume organization: `supabase/functions/pause-organization/index.ts`, `supabase/functions/resume-organization/index.ts`
- Update permission template: `supabase/functions/update-permission-template/index.ts`
- Risk and diagnostics: `supabase/functions/generate-diagnostics/index.ts`, `supabase/functions/system-health-check/index.ts`

Every action should:

- Require JWT.
- Resolve actor from token, not request body.
- Require a specific permission.
- Validate `organization_id` scope when relevant.
- Write sanitized audit.
- Return a deterministic status or reason code.
- Never return raw internal error messages.

---

## Frontend UI Strategy

Primary file:

- Modify: `flutter_app/lib/screens/super_admin_dashboard.dart`

Recommended supporting files:

- Create: `flutter_app/lib/services/super_admin_dashboard_service.dart`
- Create: `flutter_app/lib/models/super_admin_dashboard_snapshot.dart`
- Test: `flutter_app/test/super_admin_dashboard_strategy_test.dart`

Screen structure:

1. Header
   - Title: `Super Admin Panel`
   - Health badge: `Healthy`, `Attention`, or `Incident`
   - Refresh action

2. Platform Command Strip
   - `Platform Command Center`
   - Short no-PII operating note
   - Last generated timestamp

3. KPI Grid
   - Total Organizations
   - Active Projects
   - Active Users
   - Total Brokers
   - Total Leads
   - Calls Attempted
   - Site Visits Scheduled
   - Verified Visits
   - Active Broker Locks
   - Open Disputes
   - Risk Alerts
   - Held Sync Reviews
   - System Health Issues

4. Attention Queue
   - Critical abuse events
   - Open disputes
   - delayed offline syncs held for admin review
   - critical Edge Function failures
   - paused organization access attempts

5. Organizations
   - Organization name
   - Status
   - Active user count
   - Open risk count
   - Actions: view, pause/resume route, invite user route

6. Projects
   - Project name
   - City/area
   - Status
   - Active leads
   - Verified visits

7. Workflow Summary
   - Lead intake today
   - Secure calls today
   - Visits today
   - Proofs pending
   - Locks created today
   - Payouts pending review

8. Audit Timeline
   - Event type
   - Actor role
   - Organization
   - Timestamp
   - No raw identity fields in list rows

9. Quick Actions
   - Create Organization
   - Invite User
   - Assign Role
   - View Risk
   - View Health
   - Broker Reviews
   - Diagnostics

UI behavior:

- Show skeleton/loading while fetching.
- Pull-to-refresh calls only the dashboard read endpoint.
- If the endpoint returns `forbidden_permission_required`, show `Access restricted`.
- If the endpoint fails, show cached/training snapshot only in training mode.
- In production, do not silently switch to demo data after an auth or permission failure.

---

## Frontend Read Logic

Service API:

```dart
class SuperAdminDashboardService {
  const SuperAdminDashboardService(this._client);

  final SupabaseClient _client;

  Future<SuperAdminDashboardSnapshot> loadSnapshot() async {
    final response = await _client.functions.invoke('super-admin-dashboard');
    final data = response.data;
    if (data is! Map<String, dynamic> || data['ok'] != true) {
      final reason = data is Map<String, dynamic>
          ? data['reason']?.toString() ?? 'dashboard_read_failed'
          : 'dashboard_read_failed';
      throw SuperAdminDashboardException(reason);
    }
    return SuperAdminDashboardSnapshot.fromJson(data);
  }
}
```

Model shape:

```dart
class SuperAdminDashboardSnapshot {
  final DateTime generatedAt;
  final AdminHealth health;
  final Map<String, int> kpis;
  final List<AdminOrganizationRow> organizations;
  final List<AdminProjectRow> projects;
  final List<AdminAttentionItem> attentionQueue;
  final AdminWorkflowSummary workflowSummary;
  final List<AdminAuditEventRow> auditEvents;
  final Set<String> allowedActions;

  const SuperAdminDashboardSnapshot({
    required this.generatedAt,
    required this.health,
    required this.kpis,
    required this.organizations,
    required this.projects,
    required this.attentionQueue,
    required this.workflowSummary,
    required this.auditEvents,
    required this.allowedActions,
  });
}
```

The UI should render from `SuperAdminDashboardSnapshot`, not from loose `Map<String, dynamic>` lists. This prevents UI field mistakes and makes tests deterministic.

---

## Interface Wireframe

```text
┌────────────────────────────────────────────────────────────┐
│ Super Admin Panel                              Healthy [ ] │
├────────────────────────────────────────────────────────────┤
│ Platform Command Center                                    │
│ Organizations, users, projects, risks, and health. No PII. │
│ Last sync: 20 May 2026, 18:00                              │
├────────────────────────────────────────────────────────────┤
│ KPI grid                                                   │
│ [Organizations] [Projects] [Users] [Brokers]               │
│ [Leads] [Calls] [Scheduled Visits] [Verified Visits]       │
│ [Locks] [Disputes] [Risk Alerts] [Held Sync Reviews]       │
├────────────────────────────────────────────────────────────┤
│ Attention Queue                                            │
│ CRITICAL paused_org_access_attempt    Review Risk          │
│ HIGH delayed_sync_review_required     Open Sync Review     │
├────────────────────────────────────────────────────────────┤
│ Organizations                       Projects               │
│ Wadhwa Mumbai      active           Wise City   Panvel     │
│ Pilot South        active           Upper Thane Thane      │
├────────────────────────────────────────────────────────────┤
│ Workflow Summary                                           │
│ intake today | calls today | visits | proofs | locks       │
├────────────────────────────────────────────────────────────┤
│ Audit Timeline                                             │
│ organization_created  platform_admin  17:35                │
│ invite_created        platform_admin  17:20                │
├────────────────────────────────────────────────────────────┤
│ Quick Actions                                              │
│ [Create Org] [Invite User] [Assign Role] [Risk] [Health]   │
└────────────────────────────────────────────────────────────┘
```

---

## Implementation Tasks

### Task 1: Add Super Admin Dashboard Edge Function

**Files:**

- Create: `supabase/functions/super-admin-dashboard/index.ts`
- Modify: `supabase/config.toml`
- Test: `scripts/super-admin-dashboard-static-check.mjs`

- [ ] **Step 1: Create the endpoint skeleton**

```ts
import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit } from '../_shared/sprint7.ts'

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  }

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()
    const allowed = await requirePermission(admin, user.id, 'can_view_risk_dashboard')
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    await recordAudit(admin, user.id, null, null, 'super_admin_dashboard_viewed', {})

    return safeJson({
      ok: true,
      generated_at: new Date().toISOString(),
      health: { status: 'healthy', last_event: 'none', critical_failures_1h: 0 },
      kpis: {},
      organizations: [],
      projects: [],
      attention_queue: [],
      workflow_summary: {},
      audit_events: [],
      allowed_actions: ['view_diagnostics', 'review_risk'],
    })
  } catch (_) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
```

- [ ] **Step 2: Register the function**

Add this block to `supabase/config.toml`:

```toml
[functions.super-admin-dashboard]
verify_jwt = true
```

- [ ] **Step 3: Add static check**

Create `scripts/super-admin-dashboard-static-check.mjs`:

```js
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

const root = process.cwd();
const fn = join(root, 'supabase/functions/super-admin-dashboard/index.ts');
const config = join(root, 'supabase/config.toml');
const violations = [];

if (!existsSync(fn)) violations.push('missing super-admin-dashboard function');
if (existsSync(fn)) {
  const text = readFileSync(fn, 'utf8');
  if (!text.includes('currentUser(req)')) violations.push('function must derive actor from JWT');
  if (!text.includes('requirePermission')) violations.push('function must require permission');
  if (!text.includes('recordAudit')) violations.push('function must record audit');
  if (/phone|phone_ciphertext|raw_payload|provider_payload|contact_number/i.test(text)) {
    violations.push('function must not read or return contact/provider PII');
  }
}

if (!readFileSync(config, 'utf8').includes('[functions.super-admin-dashboard]')) {
  violations.push('function must be registered in supabase/config.toml');
}

if (violations.length) {
  console.error('Super admin dashboard static check failed:');
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log('Super admin dashboard static check passed');
```

- [ ] **Step 4: Run static check**

Run: `node scripts/super-admin-dashboard-static-check.mjs`

Expected: `Super admin dashboard static check passed`

### Task 2: Replace Direct Table Reads With Service Layer

**Files:**

- Create: `flutter_app/lib/services/super_admin_dashboard_service.dart`
- Create: `flutter_app/lib/models/super_admin_dashboard_snapshot.dart`
- Modify: `flutter_app/lib/screens/super_admin_dashboard.dart`
- Test: `flutter_app/test/super_admin_dashboard_strategy_test.dart`

- [ ] **Step 1: Add snapshot model**

Create `flutter_app/lib/models/super_admin_dashboard_snapshot.dart`:

```dart
class SuperAdminDashboardSnapshot {
  final DateTime generatedAt;
  final AdminHealth health;
  final Map<String, int> kpis;
  final List<AdminOrganizationRow> organizations;
  final List<AdminProjectRow> projects;
  final List<AdminAttentionItem> attentionQueue;
  final AdminWorkflowSummary workflowSummary;
  final List<AdminAuditEventRow> auditEvents;
  final Set<String> allowedActions;

  const SuperAdminDashboardSnapshot({
    required this.generatedAt,
    required this.health,
    required this.kpis,
    required this.organizations,
    required this.projects,
    required this.attentionQueue,
    required this.workflowSummary,
    required this.auditEvents,
    required this.allowedActions,
  });

  factory SuperAdminDashboardSnapshot.fromJson(Map<String, dynamic> json) {
    final kpisJson = Map<String, dynamic>.from(json['kpis'] as Map? ?? {});
    return SuperAdminDashboardSnapshot(
      generatedAt: DateTime.tryParse('${json['generated_at'] ?? ''}') ?? DateTime.now(),
      health: AdminHealth.fromJson(Map<String, dynamic>.from(json['health'] as Map? ?? {})),
      kpis: kpisJson.map((key, value) => MapEntry(key, _intValue(value))),
      organizations: _list(json['organizations']).map(AdminOrganizationRow.fromJson).toList(),
      projects: _list(json['projects']).map(AdminProjectRow.fromJson).toList(),
      attentionQueue: _list(json['attention_queue']).map(AdminAttentionItem.fromJson).toList(),
      workflowSummary: AdminWorkflowSummary.fromJson(
        Map<String, dynamic>.from(json['workflow_summary'] as Map? ?? {}),
      ),
      auditEvents: _list(json['audit_events']).map(AdminAuditEventRow.fromJson).toList(),
      allowedActions: Set<String>.from((json['allowed_actions'] as List? ?? const []).map((value) => '$value')),
    );
  }
}

class AdminHealth {
  final String status;
  final String lastEvent;
  final int criticalFailures1h;

  const AdminHealth({
    required this.status,
    required this.lastEvent,
    required this.criticalFailures1h,
  });

  factory AdminHealth.fromJson(Map<String, dynamic> json) => AdminHealth(
        status: '${json['status'] ?? 'healthy'}',
        lastEvent: '${json['last_event'] ?? 'none'}',
        criticalFailures1h: _intValue(json['critical_failures_1h']),
      );
}

class AdminOrganizationRow {
  final String id;
  final String name;
  final String status;
  final int activeUsers;
  final int openRiskAlerts;
  final String createdAt;

  const AdminOrganizationRow({
    required this.id,
    required this.name,
    required this.status,
    required this.activeUsers,
    required this.openRiskAlerts,
    required this.createdAt,
  });

  factory AdminOrganizationRow.fromJson(Map<String, dynamic> json) => AdminOrganizationRow(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? 'Organization'}',
        status: '${json['status'] ?? 'pending'}',
        activeUsers: _intValue(json['active_users']),
        openRiskAlerts: _intValue(json['open_risk_alerts']),
        createdAt: '${json['created_at'] ?? ''}',
      );
}

class AdminProjectRow {
  final String id;
  final String name;
  final String city;
  final String area;
  final String status;
  final int activeLeads;
  final int verifiedVisits;

  const AdminProjectRow({
    required this.id,
    required this.name,
    required this.city,
    required this.area,
    required this.status,
    required this.activeLeads,
    required this.verifiedVisits,
  });

  factory AdminProjectRow.fromJson(Map<String, dynamic> json) => AdminProjectRow(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? 'Project'}',
        city: '${json['city'] ?? '-'}',
        area: '${json['area'] ?? '-'}',
        status: '${json['status'] ?? 'inactive'}',
        activeLeads: _intValue(json['active_leads']),
        verifiedVisits: _intValue(json['verified_visits']),
      );
}

class AdminAttentionItem {
  final String id;
  final String type;
  final String severity;
  final String title;
  final String reasonCode;
  final String organizationId;
  final String createdAt;

  const AdminAttentionItem({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.reasonCode,
    required this.organizationId,
    required this.createdAt,
  });

  factory AdminAttentionItem.fromJson(Map<String, dynamic> json) => AdminAttentionItem(
        id: '${json['id'] ?? ''}',
        type: '${json['type'] ?? 'unknown'}',
        severity: '${json['severity'] ?? 'medium'}',
        title: '${json['title'] ?? 'Admin review required'}',
        reasonCode: '${json['reason_code'] ?? 'review_required'}',
        organizationId: '${json['organization_id'] ?? ''}',
        createdAt: '${json['created_at'] ?? ''}',
      );
}

class AdminWorkflowSummary {
  final int leadIntakeToday;
  final int secureCallsToday;
  final int siteVisitsToday;
  final int proofsPending;
  final int locksCreatedToday;
  final int payoutsPendingReview;

  const AdminWorkflowSummary({
    required this.leadIntakeToday,
    required this.secureCallsToday,
    required this.siteVisitsToday,
    required this.proofsPending,
    required this.locksCreatedToday,
    required this.payoutsPendingReview,
  });

  factory AdminWorkflowSummary.fromJson(Map<String, dynamic> json) => AdminWorkflowSummary(
        leadIntakeToday: _intValue(json['lead_intake_today']),
        secureCallsToday: _intValue(json['secure_calls_today']),
        siteVisitsToday: _intValue(json['site_visits_today']),
        proofsPending: _intValue(json['proofs_pending']),
        locksCreatedToday: _intValue(json['locks_created_today']),
        payoutsPendingReview: _intValue(json['payouts_pending_review']),
      );
}

class AdminAuditEventRow {
  final String id;
  final String eventType;
  final String actorRole;
  final String organizationId;
  final String createdAt;

  const AdminAuditEventRow({
    required this.id,
    required this.eventType,
    required this.actorRole,
    required this.organizationId,
    required this.createdAt,
  });

  factory AdminAuditEventRow.fromJson(Map<String, dynamic> json) => AdminAuditEventRow(
        id: '${json['id'] ?? ''}',
        eventType: '${json['event_type'] ?? 'audit_event'}',
        actorRole: '${json['actor_role'] ?? 'unknown'}',
        organizationId: '${json['organization_id'] ?? ''}',
        createdAt: '${json['created_at'] ?? ''}',
      );
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
```

- [ ] **Step 2: Add service**

Create `flutter_app/lib/services/super_admin_dashboard_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/super_admin_dashboard_snapshot.dart';

class SuperAdminDashboardException implements Exception {
  final String reason;

  const SuperAdminDashboardException(this.reason);

  @override
  String toString() => reason;
}

class SuperAdminDashboardService {
  const SuperAdminDashboardService(this._client);

  final SupabaseClient _client;

  Future<SuperAdminDashboardSnapshot> loadSnapshot() async {
    final response = await _client.functions.invoke('super-admin-dashboard');
    final data = response.data;
    if (data is! Map<String, dynamic> || data['ok'] != true) {
      final reason = data is Map<String, dynamic>
          ? data['reason']?.toString() ?? 'dashboard_read_failed'
          : 'dashboard_read_failed';
      throw SuperAdminDashboardException(reason);
    }
    return SuperAdminDashboardSnapshot.fromJson(data);
  }
}
```

- [ ] **Step 3: Update screen state**

Replace loose dashboard maps in `flutter_app/lib/screens/super_admin_dashboard.dart`:

```dart
SuperAdminDashboardSnapshot? _snapshot;
String? _errorReason;
```

Replace `_loadLive()` with:

```dart
Future<void> _loadLive() async {
  final service = SuperAdminDashboardService(Supabase.instance.client);
  final snapshot = await service.loadSnapshot();
  if (!mounted) return;
  setState(() {
    _snapshot = snapshot;
    _errorReason = null;
    _isLoading = false;
  });
}
```

Use `_snapshot!.kpis['total_organizations'] ?? 0` style reads in cards.

- [ ] **Step 4: Preserve training demo**

Keep training mode by creating a typed fixture:

```dart
SuperAdminDashboardSnapshot buildDemoSuperAdminSnapshot() {
  return SuperAdminDashboardSnapshot.fromJson({
    'ok': true,
    'generated_at': DateTime.now().toIso8601String(),
    'health': {
      'status': 'healthy',
      'last_event': 'none',
      'critical_failures_1h': 0,
    },
    'kpis': {
      'total_organizations': 4,
      'active_projects': 8,
      'active_users': 54,
      'total_brokers': 156,
      'total_leads': 1240,
      'calls_attempted': 832,
      'scheduled_visits': 61,
      'verified_visits': 37,
      'active_locks': 28,
      'open_disputes': 3,
      'open_risk_alerts': 2,
      'held_sync_reviews': 1,
    },
    'organizations': [
      {
        'id': 'demo-org-1',
        'name': 'Wadhwa Mumbai',
        'status': 'active',
        'active_users': 18,
        'open_risk_alerts': 1,
        'created_at': DateTime.now().toIso8601String(),
      }
    ],
    'projects': [
      {
        'id': 'demo-project-1',
        'name': 'The Wadhwa Wise City',
        'city': 'Mumbai',
        'area': 'Panvel',
        'status': 'active',
        'active_leads': 280,
        'verified_visits': 12,
      }
    ],
    'attention_queue': [
      {
        'id': 'demo-risk-1',
        'type': 'abuse_event',
        'severity': 'critical',
        'title': 'Paused org access attempt',
        'reason_code': 'paused_org_access_attempt',
        'organization_id': 'demo-org-1',
        'created_at': DateTime.now().toIso8601String(),
      }
    ],
    'workflow_summary': {
      'lead_intake_today': 24,
      'secure_calls_today': 31,
      'site_visits_today': 7,
      'proofs_pending': 4,
      'locks_created_today': 2,
      'payouts_pending_review': 3,
    },
    'audit_events': [
      {
        'id': 'demo-audit-1',
        'event_type': 'organization_created',
        'actor_role': 'platform_admin',
        'organization_id': 'demo-org-1',
        'created_at': DateTime.now().toIso8601String(),
      }
    ],
    'allowed_actions': [
      'create_organization',
      'invite_user',
      'assign_role',
      'view_diagnostics',
      'review_risk',
    ],
  });
}
```

- [ ] **Step 5: Add widget/model tests**

Test that:

- KPI labels render.
- Forbidden response shows access restricted.
- Phone-like strings are not rendered from dashboard rows.
- Training mode renders demo snapshot.

### Task 3: Add Attention Queue UI

**Files:**

- Modify: `flutter_app/lib/screens/super_admin_dashboard.dart`
- Test: `flutter_app/test/super_admin_dashboard_strategy_test.dart`

- [ ] **Step 1: Add attention section after KPI grid**

Add this widget pattern in `super_admin_dashboard.dart`:

```dart
Widget _attentionQueue(SuperAdminDashboardSnapshot snapshot) {
  if (snapshot.attentionQueue.isEmpty) {
    return const Text('No admin attention items.', style: TextStyle(color: PremiumUI.muted));
  }

  return PremiumUI.sectionShell(
    title: 'Attention Queue',
    subtitle: 'Risk, dispute, sync, and health items needing admin review',
    accentColor: PremiumUI.danger,
    child: Column(
      children: snapshot.attentionQueue.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PremiumUI.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              PremiumUI.statusBadge(item.severity, PremiumUI.statusColor(item.severity)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(item.reasonCode, style: const TextStyle(color: PremiumUI.muted, fontSize: 12)),
                  ],
                ),
              ),
              _attentionAction(item),
            ],
          ),
        );
      }).toList(),
    ),
  );
}
```

- [ ] **Step 2: Route action buttons**

Map item types:

- `abuse_event` -> `AbuseMonitoringDashboard`
- `dispute` -> dispute/admin screen when available
- `held_sync_review` -> diagnostics screen until a dedicated sync review screen exists
- `system_health` -> `SystemHealthDashboard`

- [ ] **Step 3: Fail closed on unknown type**

Use this router:

```dart
Widget _attentionAction(AdminAttentionItem item) {
  final destination = switch (item.type) {
    'abuse_event' => const AbuseMonitoringDashboard(),
    'held_sync_review' => const AdminDiagnosticsScreen(),
    'system_health' => const SystemHealthDashboard(),
    _ => null,
  };

  if (destination == null) {
    return const Text('Read only', style: TextStyle(color: PremiumUI.muted, fontSize: 12));
  }

  return TextButton(
    onPressed: () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
    },
    child: const Text('Review'),
  );
}
```

### Task 4: Add Workflow Summary UI

**Files:**

- Modify: `flutter_app/lib/screens/super_admin_dashboard.dart`
- Test: `flutter_app/test/super_admin_dashboard_strategy_test.dart`

- [ ] **Step 1: Add workflow cards**

Render:

- Lead intake today
- Secure calls today
- Site visits today
- Proofs pending
- Locks created today
- Payouts pending review

Use this widget:

```dart
Widget _workflowSummary(AdminWorkflowSummary summary) {
  final rows = [
    ('Lead Intake Today', summary.leadIntakeToday, Icons.input_outlined),
    ('Secure Calls Today', summary.secureCallsToday, Icons.call_outlined),
    ('Site Visits Today', summary.siteVisitsToday, Icons.event_available_outlined),
    ('Proofs Pending', summary.proofsPending, Icons.fact_check_outlined),
    ('Locks Created Today', summary.locksCreatedToday, Icons.lock_clock_outlined),
    ('Payouts Pending Review', summary.payoutsPendingReview, Icons.payments_outlined),
  ];

  return PremiumUI.sectionShell(
    title: 'Workflow Summary',
    subtitle: 'Daily trust-loop movement without raw buyer data',
    accentColor: PremiumUI.accent,
    child: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: rows.map((row) {
        return SizedBox(
          width: 180,
          child: PremiumUI.kpiCard(row.$1, row.$2.toString(), row.$3, PremiumUI.accent),
        );
      }).toList(),
    ),
  );
}
```

- [ ] **Step 2: Make cards route-only**

Cards may route to existing safe screens, but they must not mutate state directly. Use `Navigator.push(...)`; do not call `.from(...).update(...)` or `.from(...).insert(...)` from card taps.

### Task 5: Verification

**Files:**

- Modify: `package.json` if adding the static check to scripts
- Modify: `docs/reports/REAL_BUILD_VERIFICATION_REPORT.md` only after live verification exists

- [ ] **Step 1: Run required gates**

Run from repo root:

```powershell
npm run build
npx tsc --noEmit
```

Expected: both exit `0`.

- [ ] **Step 2: Run Flutter checks**

Run:

```powershell
cd flutter_app
flutter analyze
flutter test
```

Expected: analyzer has no issues and tests pass.

- [ ] **Step 3: Run project static checks**

Run:

```powershell
npm run security
npm run sprint7:check
node scripts/super-admin-dashboard-static-check.mjs
```

Expected: all checks pass.

---

## Production Rules

- Do not show phone numbers, buyer names, raw payloads, or decrypted contact data.
- Do not let the dashboard write directly to Supabase tables.
- Do not make generic AI recommendations on admin actions. Use deterministic reason codes and existing protected action endpoints.
- Do not silently use demo data in production when auth, permission, or backend reads fail.
- Do not add a broad `authenticated` RLS policy to make the dashboard work. Fix the Edge Function read model instead.

---

## Done Definition

The Super Admin dashboard is complete when:

- The Flutter screen renders from a typed dashboard snapshot.
- The dashboard read path goes through `super-admin-dashboard`.
- All admin actions route to protected Edge Functions or existing safe screens.
- PII and raw provider payloads cannot appear in dashboard JSON or UI.
- Root gates pass: `npm run build`, `npx tsc --noEmit`.
- Flutter gates pass: `flutter analyze`, `flutter test`.
- Static checks prove JWT, permission, audit, and no-PII rules for the dashboard endpoint.
