import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, cleanText, corsHeaders, currentUser, requirePermission, safeJson } from '../_shared/sprint7.ts'

const ADMIN_ROLE_IDS = ['platform_admin', 'ops_admin']
const OPEN_DISPUTE_STATUSES = ['opened', 'under_review', 'evidence_requested']
const OPEN_RISK_STATUSES = ['unread', 'acknowledged']
const OPEN_ABUSE_STATUSES = ['open', 'investigating']
const ACTIVE_LEAD_STATUSES = ['new', 'loan_active', 'call_queued', 'visit_scheduled', 'visit_verified', 'locked']
const SEVERITY_RANK: Record<string, number> = { critical: 4, high: 3, medium: 2, low: 1 }

type Admin = ReturnType<typeof adminClient>
type CountResult = { count: number | null; error: unknown }
type AdminContext = { organizationId: string; roleId: string }

function countValue(result: CountResult) {
  if (result.error) throw new Error('dashboard_read_failed')
  return result.count ?? 0
}

function safeText(value: unknown, max = 120) {
  return cleanText(value, max)
}

function safeId(value: unknown) {
  return typeof value === 'string' ? value : null
}

function safeRef(prefix: string, value: unknown) {
  const id = safeId(value)
  return id ? `${prefix}:${id.slice(0, 8)}` : `${prefix}:unknown`
}

function severityForCount(count: number, high = 10, critical = 25) {
  if (count >= critical) return 'critical'
  if (count >= high) return 'high'
  if (count > 0) return 'medium'
  return 'low'
}

async function exactCount(query: PromiseLike<CountResult>) {
  return countValue(await query)
}

async function requirePlatformAdmin(admin: Admin, userId: string): Promise<AdminContext | null> {
  const { data: assignment, error: assignmentError } = await admin
    .from('role_assignments')
    .select('organization_id, role_id, status, organizations(status)')
    .eq('user_id', userId)
    .in('role_id', ADMIN_ROLE_IDS)
    .eq('status', 'active')
    .limit(1)
    .maybeSingle()

  if (assignmentError) throw new Error('dashboard_read_failed')
  if (!assignment || assignment.status !== 'active' || assignment.organizations?.status !== 'active') return null

  const organizationId = safeId(assignment.organization_id)
  const roleId = safeText(assignment.role_id)
  if (!organizationId || !roleId) return null

  const { data: pilotUser, error: pilotError } = await admin
    .from('pilot_users')
    .select('org_id, status')
    .eq('user_id', userId)
    .eq('org_id', organizationId)
    .eq('status', 'active')
    .limit(1)
    .maybeSingle()

  if (pilotError) throw new Error('dashboard_read_failed')
  if (!pilotUser || pilotUser.status !== 'active') return null

  return { organizationId, roleId }
}

async function roleAllows(admin: Admin, roleId: string, permission: string) {
  return exactCount(
    admin
      .from('role_permissions')
      .select('permission_id', { count: 'exact', head: true })
      .eq('role_id', roleId)
      .eq('permission_id', permission),
  ) > 0
}

async function allowedPermission(admin: Admin, userId: string, organizationId: string, roleId: string, permission: string) {
  return await requirePermission(admin, userId, permission, organizationId) || await roleAllows(admin, roleId, permission)
}

async function getAllowedActions(admin: Admin, userId: string, context: AdminContext) {
  const canManageUsers = await allowedPermission(admin, userId, context.organizationId, context.roleId, 'can_manage_org_users')
  const canViewRisk = await allowedPermission(admin, userId, context.organizationId, context.roleId, 'can_view_risk_dashboard')
  const canPauseOrg = await allowedPermission(admin, userId, context.organizationId, context.roleId, 'can_pause_org')
  const canSuspendUser = await allowedPermission(admin, userId, context.organizationId, context.roleId, 'can_suspend_user')
  const canReviewVisits = await allowedPermission(admin, userId, context.organizationId, context.roleId, 'can_review_site_visits')
  const canViewPayouts = await allowedPermission(admin, userId, context.organizationId, context.roleId, 'can_view_payouts')
  const canGrantLoans = await allowedPermission(admin, userId, context.organizationId, context.roleId, 'can_grant_data_loans')
  const canViewAudit = await allowedPermission(admin, userId, context.organizationId, context.roleId, 'can_view_audit_logs')

  const allowed = new Set<string>()
  const isOpsRole = ADMIN_ROLE_IDS.includes(context.roleId)

  if (isOpsRole || canViewRisk || canManageUsers) allowed.add('view_super_admin_dashboard')
  if (isOpsRole || canViewRisk || canViewAudit) allowed.add('view_platform_health')
  if (isOpsRole || canViewRisk) {
    allowed.add('view_risk_dashboard')
    allowed.add('view_system_health')
    allowed.add('view_diagnostics')
    allowed.add('view_workforce_reports')
    allowed.add('open_assignment_queue')
    allowed.add('view_developer_projects')
  }
  if (canManageUsers) {
    allowed.add('manage_organizations')
    allowed.add('invite_users')
    allowed.add('assign_roles')
    allowed.add('can_manage_org_users')
  }
  if (canPauseOrg) {
    allowed.add('pause_organization')
    allowed.add('resume_organization')
    allowed.add('manage_incidents')
    allowed.add('can_pause_org')
  }
  if (canSuspendUser || canManageUsers) allowed.add('suspend_users')
  if (canViewAudit || canViewRisk) allowed.add('view_audit_events')
  if (canViewPayouts || canViewRisk) {
    allowed.add('view_broker_locks')
    allowed.add('can_view_payouts')
  }
  if (canGrantLoans) {
    allowed.add('manage_data_loans')
    allowed.add('can_grant_data_loans')
  }
  if (canReviewVisits) {
    allowed.add('broker_reviews')
    allowed.add('can_review_site_visits')
  }
  if (canViewRisk) allowed.add('can_view_risk_dashboard')

  return Array.from(allowed)
}

async function activeUserCountByOrg(admin: Admin, organizationId: string) {
  return exactCount(
    admin
      .from('pilot_users')
      .select('id', { count: 'exact', head: true })
      .eq('org_id', organizationId)
      .eq('status', 'active'),
  )
}

async function projectCountByOrg(admin: Admin, organizationId: string) {
  return exactCount(
    admin
      .from('projects')
      .select('id', { count: 'exact', head: true })
      .eq('developer_id', organizationId),
  )
}

async function openRiskCountByOrg(admin: Admin, organizationId: string) {
  return exactCount(
    admin
      .from('risk_notifications')
      .select('id', { count: 'exact', head: true })
      .eq('organization_id', organizationId)
      .in('status', OPEN_RISK_STATUSES),
  )
}

async function activeLeadCountByProject(admin: Admin, projectId: string) {
  return exactCount(
    admin
      .from('leads_public')
      .select('id', { count: 'exact', head: true })
      .eq('project_id', projectId)
      .in('lead_status', ACTIVE_LEAD_STATUSES),
  )
}

async function verifiedVisitCountByProject(admin: Admin, projectId: string) {
  return exactCount(
    admin
      .from('site_visits')
      .select('id', { count: 'exact', head: true })
      .eq('project_id', projectId)
      .in('status', ['verified', 'completed']),
  )
}

async function activeBrokerCountByProject(admin: Admin, projectId: string) {
  return exactCount(
    admin
      .from('broker_activations')
      .select('id', { count: 'exact', head: true })
      .eq('project_id', projectId)
      .in('activation_stage', ['active_broker', 'lead_expected', 'meeting_scheduled']),
  )
}

async function actorRoleMap(admin: Admin, actorIds: string[]) {
  if (actorIds.length === 0) return new Map<string, string>()

  const { data, error } = await admin
    .from('role_assignments')
    .select('user_id, role_id')
    .in('user_id', actorIds)
    .eq('status', 'active')

  if (error) throw new Error('dashboard_read_failed')

  return new Map((data ?? []).map((row: any) => [row.user_id, safeText(row.role_id) || 'unknown']))
}

async function auditLeadOrgMap(admin: Admin, leadIds: string[]) {
  if (leadIds.length === 0) return new Map<string, string>()

  const { data, error } = await admin
    .from('leads_public')
    .select('id, organization_id')
    .in('id', leadIds)

  if (error) throw new Error('dashboard_read_failed')

  return new Map((data ?? []).map((row: any) => [row.id, safeId(row.organization_id)]))
}

async function recordAudit(
  admin: Admin,
  actorId: string,
  organizationId: string,
  eventType: string,
  context: Record<string, unknown>,
) {
  const { error } = await admin.from('audit_events').insert({
    actor_id: actorId,
    event_type: eventType,
    event_context: {
      ...context,
      organization_id: organizationId,
    },
  })

  if (error) throw new Error('dashboard_read_failed')
}

async function getPlatformHealthSnapshot(admin: Admin, oneHourAgo: string) {
  const [
    healthEvent,
    failedFunctions,
    providerFailures,
    callbackFailures,
    releaseGate,
    migrationDrift,
    securityScan,
  ] = await Promise.all([
    admin.from('system_health_events').select('status, event_type, created_at').order('created_at', { ascending: false }).limit(1).maybeSingle(),
    admin.from('edge_function_failures').select('id', { count: 'exact', head: true }).gte('created_at', oneHourAgo).in('severity', ['high', 'critical']),
    admin.from('provider_failures').select('id', { count: 'exact', head: true }).gte('created_at', oneHourAgo).eq('resolved', false),
    admin.from('call_attempts').select('id', { count: 'exact', head: true }).gte('created_at', oneHourAgo).eq('call_status', 'provider_failed'),
    admin.from('deployment_events').select('status, created_at').eq('deployment_type', 'release_gate').order('created_at', { ascending: false }).limit(1).maybeSingle(),
    admin.from('deployment_events').select('status, created_at').eq('deployment_type', 'migration').order('created_at', { ascending: false }).limit(1).maybeSingle(),
    admin.from('deployment_events').select('status, created_at').eq('deployment_type', 'security_scan').order('created_at', { ascending: false }).limit(1).maybeSingle(),
  ])

  const reads = [healthEvent, failedFunctions, providerFailures, callbackFailures, releaseGate, migrationDrift, securityScan]
  if (reads.some((result: any) => result.error)) throw new Error('dashboard_read_failed')

  const failed = countValue(failedFunctions)
  const providers = countValue(providerFailures)
  const callbacks = countValue(callbackFailures)
  const status = failed + providers + callbacks > 10 ? 'critical' : failed + providers + callbacks > 0 ? 'warning' : (healthEvent.data?.status ?? 'healthy')

  return {
    status,
    failed_functions: failed,
    provider_failures: providers,
    callback_failures: callbacks,
    last_release_gate: safeText(releaseGate.data?.status) || 'unknown',
    migration_drift: safeText(migrationDrift.data?.status) || 'unknown',
    security_scan_status: safeText(securityScan.data?.status) || 'unknown',
    last_event: healthEvent.data?.event_type ?? 'none',
  }
}

async function getOrganizationSummary(admin: Admin) {
  const { data, error } = await admin
    .from('organizations')
    .select('id, name, status, created_at')
    .order('created_at', { ascending: false })
    .limit(8)

  if (error) throw new Error('dashboard_read_failed')

  return Promise.all((data ?? []).map(async (row: any) => ({
    id: row.id,
    name: safeText(row.name, 80),
    status: safeText(row.status),
    projects_count: await projectCountByOrg(admin, row.id),
    active_users: await activeUserCountByOrg(admin, row.id),
    open_risk_alerts: await openRiskCountByOrg(admin, row.id),
    billing_status: 'unknown',
    created_at: row.created_at,
  })))
}

async function getProjectSummary(admin: Admin) {
  const { data, error } = await admin
    .from('projects')
    .select('id, project_name, city, area, status')
    .order('created_at', { ascending: false })
    .limit(8)

  if (error) throw new Error('dashboard_read_failed')

  return Promise.all((data ?? []).map(async (row: any) => {
    const activeLeads = await activeLeadCountByProject(admin, row.id)
    const verifiedVisits = await verifiedVisitCountByProject(admin, row.id)
    const activeBrokers = await activeBrokerCountByProject(admin, row.id)
    return {
      id: row.id,
      name: safeText(row.project_name, 80),
      city: safeText(row.city, 60),
      area: safeText(row.area, 60),
      status: safeText(row.status),
      active_leads: activeLeads,
      verified_visits: verifiedVisits,
      active_brokers: activeBrokers,
      inventory_units: 0,
      conversion_rate: activeLeads > 0 ? Math.round((verifiedVisits / activeLeads) * 100) : 0,
      inventory_status: 'unknown',
      free_lead_bank_status: activeLeads > 0 ? 'active' : 'pending',
    }
  }))
}

async function getWorkforcePerformance(admin: Admin, today: string) {
  const [brokersResult, callersResult, smResult] = await Promise.all([
    admin.from('brokers_public').select('id, broker_alias, status, total_leads, verified_visits, active_locks, trust_score').order('updated_at', { ascending: false }).limit(5),
    admin.from('pilot_users').select('user_id, role, status').eq('role', 'caller').limit(5),
    admin.from('pilot_users').select('user_id, role, status').eq('role', 'sourcing_manager').limit(5),
  ])

  if (brokersResult.error || callersResult.error || smResult.error) throw new Error('dashboard_read_failed')

  const brokers = (brokersResult.data ?? []).map((row: any) => ({
    id: row.id,
    label: safeText(row.broker_alias, 80) || safeRef('broker', row.id),
    role: 'broker',
    status: safeText(row.status) || 'unknown',
    risk_level: Number(row.trust_score ?? 0) < 40 ? 'high' : 'low',
    efficiency_score: Math.max(0, Math.min(100, Math.round(Number(row.trust_score ?? 0)))),
    metrics: {
      leads: Number(row.total_leads ?? 0),
      visits: Number(row.verified_visits ?? 0),
      locks: Number(row.active_locks ?? 0),
      trust: Math.round(Number(row.trust_score ?? 0)),
    },
  }))

  const callers = await Promise.all((callersResult.data ?? []).map(async (row: any) => {
    const assigned = await exactCount(admin.from('leads_public').select('id', { count: 'exact', head: true }).eq('assigned_caller_id', row.user_id).in('lead_status', ACTIVE_LEAD_STATUSES))
    const attempted = await exactCount(admin.from('call_attempts').select('id', { count: 'exact', head: true }).eq('caller_id', row.user_id).gte('created_at', today))
    const connected = await exactCount(admin.from('call_attempts').select('id', { count: 'exact', head: true }).eq('caller_id', row.user_id).gte('created_at', today).eq('call_status', 'completed'))
    const interested = await exactCount(admin.from('call_attempts').select('id', { count: 'exact', head: true }).eq('caller_id', row.user_id).gte('created_at', today).eq('outcome', 'interested'))
    return {
      id: row.user_id,
      label: safeRef('caller', row.user_id),
      role: 'caller',
      status: safeText(row.status) || 'unknown',
      risk_level: assigned > 30 ? 'medium' : 'low',
      efficiency_score: attempted > 0 ? Math.round((connected / attempted) * 100) : 0,
      metrics: { assigned, attempted, connected, interested },
    }
  }))

  const sourcingManagers = await Promise.all((smResult.data ?? []).map(async (row: any) => {
    const meetings = await exactCount(admin.from('broker_activations').select('id', { count: 'exact', head: true }).eq('assigned_sourcing_manager_id', row.user_id).eq('activation_stage', 'meeting_scheduled'))
    const scheduled = await exactCount(admin.from('site_visits').select('id', { count: 'exact', head: true }).eq('sourcing_manager_id', row.user_id).gte('created_at', today))
    const verified = await exactCount(admin.from('site_visits').select('id', { count: 'exact', head: true }).eq('sourcing_manager_id', row.user_id).gte('created_at', today).in('status', ['verified', 'completed']))
    const projects = await exactCount(admin.from('broker_activations').select('project_id', { count: 'exact', head: true }).eq('assigned_sourcing_manager_id', row.user_id))
    return {
      id: row.user_id,
      label: safeRef('sm', row.user_id),
      role: 'sourcing_manager',
      status: safeText(row.status) || 'unknown',
      risk_level: scheduled > 0 && verified === 0 ? 'medium' : 'low',
      efficiency_score: scheduled > 0 ? Math.round((verified / scheduled) * 100) : 0,
      metrics: { meetings, scheduled, verified, projects },
    }
  }))

  return { brokers, callers, sourcing_managers: sourcingManagers }
}

async function getAttentionQueue(admin: Admin) {
  const [riskQueueResult, disputeQueueResult, failedCallbacks, delayedVisits] = await Promise.all([
    admin.from('risk_notifications').select('id, severity, notification_type, reason_code, organization_id, created_at').in('status', OPEN_RISK_STATUSES).order('created_at', { ascending: false }).limit(10),
    admin.from('disputes').select('id, type, status, org_id, created_at').in('status', OPEN_DISPUTE_STATUSES).order('created_at', { ascending: false }).limit(5),
    admin.from('call_attempts').select('id, call_status, created_at').eq('call_status', 'provider_failed').order('created_at', { ascending: false }).limit(5),
    admin.from('site_visits').select('id, status, organization_id, created_at').eq('offline_sync_status', 'held_for_admin_review').order('created_at', { ascending: false }).limit(5),
  ])

  if (riskQueueResult.error || disputeQueueResult.error || failedCallbacks.error || delayedVisits.error) throw new Error('dashboard_read_failed')

  const riskItems = (riskQueueResult.data ?? []).map((row: any) => ({
    id: row.id,
    type: 'duplicate_risk',
    severity: safeText(row.severity) || 'medium',
    title: safeText(row.notification_type, 80) || 'Risk notification',
    reason_code: safeText(row.reason_code) || 'review_risk',
    organization_id: row.organization_id,
    safe_ref: safeRef('risk', row.id),
    action: 'review_risk',
    route: 'risk_center',
    created_at: row.created_at,
  }))

  const disputeItems = (disputeQueueResult.data ?? []).map((row: any) => ({
    id: row.id,
    type: 'broker_lock_dispute',
    severity: row.status === 'evidence_requested' ? 'high' : 'medium',
    title: safeText(row.type, 80) || 'Dispute review',
    reason_code: safeText(row.status) || 'review_dispute',
    organization_id: row.org_id,
    safe_ref: safeRef('dispute', row.id),
    action: 'open_broker_locks',
    route: 'broker_locks',
    created_at: row.created_at,
  }))

  const callbackItems = (failedCallbacks.data ?? []).map((row: any) => ({
    id: row.id,
    type: 'failed_callback',
    severity: 'high',
    title: 'Provider callback failure',
    reason_code: safeText(row.call_status) || 'callback_failed',
    organization_id: '',
    safe_ref: safeRef('callback', row.id),
    action: 'open_diagnostics',
    route: 'diagnostics',
    created_at: row.created_at,
  }))

  const syncItems = (delayedVisits.data ?? []).map((row: any) => ({
    id: row.id,
    type: 'stuck_visit',
    severity: 'medium',
    title: 'Visit held for admin review',
    reason_code: safeText(row.status) || 'held_review',
    organization_id: row.organization_id,
    safe_ref: safeRef('visit', row.id),
    action: 'open_diagnostics',
    route: 'diagnostics',
    created_at: row.created_at,
  }))

  return riskItems
    .concat(disputeItems, callbackItems, syncItems)
    .sort((left, right) => {
      const severityDelta = (SEVERITY_RANK[right.severity] ?? 0) - (SEVERITY_RANK[left.severity] ?? 0)
      if (severityDelta !== 0) return severityDelta
      return String(right.created_at).localeCompare(String(left.created_at))
    })
    .slice(0, 12)
}

async function getWorkflowBottlenecks(admin: Admin, nowIso: string, oneDayAgo: string) {
  const [
    unassignedLeads,
    missingBrokerLink,
    expiredLoans,
    overdueFollowups,
    stuckVisits,
    gpsProofGap,
    photoProofGap,
    failedCallbacks,
  ] = await Promise.all([
    admin.from('leads_public').select('id', { count: 'exact', head: true }).is('assigned_caller_id', null).in('lead_status', ACTIVE_LEAD_STATUSES),
    admin.from('leads_public').select('id', { count: 'exact', head: true }).is('source_broker_id', null).gte('created_at', oneDayAgo),
    admin.from('data_loans').select('id', { count: 'exact', head: true }).eq('status', 'expired').gte('created_at', oneDayAgo),
    admin.from('broker_followups').select('id', { count: 'exact', head: true }).eq('status', 'pending').lt('due_at', nowIso),
    admin.from('site_visits').select('id', { count: 'exact', head: true }).eq('status', 'scheduled').lt('scheduled_at', oneDayAgo),
    admin.from('site_visits').select('id', { count: 'exact', head: true }).in('status', ['started', 'gps_submitted']),
    admin.from('site_visits').select('id', { count: 'exact', head: true }).eq('status', 'gps_verified'),
    admin.from('call_attempts').select('id', { count: 'exact', head: true }).eq('call_status', 'provider_failed').gte('created_at', oneDayAgo),
  ])

  const rows = [
    { id: 'bottleneck_unassigned_leads', type: 'stuck_lead', title: 'Leads without caller assignment', count: countValue(unassignedLeads), action: 'open_assignment_queue', route: 'assignment_queue' },
    { id: 'bottleneck_missing_broker_link', type: 'stuck_lead', title: 'Leads without broker attribution', count: countValue(missingBrokerLink), action: 'open_assignment_queue', route: 'assignment_queue' },
    { id: 'bottleneck_expired_loans', type: 'data_loan_gap', title: 'Expired data loans needing review', count: countValue(expiredLoans), action: 'manage_data_loans', route: 'broker_locks' },
    { id: 'bottleneck_overdue_followups', type: 'overdue_followup', title: 'Overdue broker followups', count: countValue(overdueFollowups), action: 'open_assignment_queue', route: 'assignment_queue' },
    { id: 'bottleneck_stuck_visits', type: 'stuck_visit', title: 'Scheduled visits not started', count: countValue(stuckVisits), action: 'open_diagnostics', route: 'diagnostics' },
    { id: 'bottleneck_gps_gap', type: 'gps_failure', title: 'Visits waiting for GPS proof', count: countValue(gpsProofGap), action: 'open_diagnostics', route: 'diagnostics' },
    { id: 'bottleneck_photo_gap', type: 'proof_pending', title: 'Visits waiting for photo proof', count: countValue(photoProofGap), action: 'open_diagnostics', route: 'diagnostics' },
    { id: 'bottleneck_callback_failed', type: 'failed_callback', title: 'Provider callbacks failed', count: countValue(failedCallbacks), action: 'open_diagnostics', route: 'diagnostics' },
  ]

  return rows
    .filter((row) => row.count > 0)
    .map((row) => ({
      id: row.id,
      type: row.type,
      severity: severityForCount(row.count),
      title: row.title,
      safe_ref: `flow:${row.type}`,
      action: row.action,
      route: row.route,
      metrics: { count: row.count },
      created_at: nowIso,
    }))
}

async function getWorkflowSummary(admin: Admin, today: string, bottlenecks: any[]) {
  const [
    leadIntakeToday,
    secureCallsToday,
    siteVisitsToday,
    proofsPending,
    locksCreatedToday,
    payoutsPendingReview,
  ] = await Promise.all([
    admin.from('leads_public').select('id', { count: 'exact', head: true }).gte('created_at', today),
    admin.from('call_attempts').select('id', { count: 'exact', head: true }).gte('created_at', today),
    admin.from('site_visits').select('id', { count: 'exact', head: true }).gte('created_at', today),
    admin.from('site_visits').select('id', { count: 'exact', head: true }).in('status', ['arrived', 'gps_verified', 'photo_uploaded', 'photo_verified']),
    admin.from('broker_locks').select('id', { count: 'exact', head: true }).gte('created_at', today),
    admin.from('payout_ledger').select('id', { count: 'exact', head: true }).in('status', ['pending', 'eligible']),
  ])

  const countFor = (id: string) => bottlenecks.find((row) => row.id === id)?.metrics?.count ?? 0

  return {
    lead_intake_today: countValue(leadIntakeToday),
    secure_calls_today: countValue(secureCallsToday),
    site_visits_today: countValue(siteVisitsToday),
    proofs_pending: countValue(proofsPending),
    locks_created_today: countValue(locksCreatedToday),
    payouts_pending_review: countValue(payoutsPendingReview),
    unassigned_leads: countFor('bottleneck_unassigned_leads'),
    overloaded_callers: 0,
    idle_callers: 0,
    delayed_followups: countFor('bottleneck_overdue_followups'),
    stuck_visits: countFor('bottleneck_stuck_visits'),
  }
}

async function getTrustOperations(admin: Admin, nowIso: string) {
  const [activeLocks, disputedLocks, expiringLocks, proofsPending, payoutsPending] = await Promise.all([
    admin.from('broker_locks').select('id', { count: 'exact', head: true }).eq('status', 'active'),
    admin.from('disputes').select('id', { count: 'exact', head: true }).in('status', OPEN_DISPUTE_STATUSES),
    admin.from('broker_locks').select('id', { count: 'exact', head: true }).eq('status', 'active').lte('expires_at', new Date(Date.now() + 72 * 60 * 60 * 1000).toISOString()),
    admin.from('site_visits').select('id', { count: 'exact', head: true }).in('status', ['arrived', 'gps_verified', 'photo_uploaded', 'photo_verified']),
    admin.from('payout_ledger').select('id', { count: 'exact', head: true }).in('status', ['pending', 'eligible']),
  ])

  const rows = [
    { id: 'trust_active_locks', type: 'broker_lock', title: 'Active broker locks', count: countValue(activeLocks), severity: 'low' },
    { id: 'trust_disputed_locks', type: 'broker_lock_dispute', title: 'Disputed locks', count: countValue(disputedLocks), severity: severityForCount(countValue(disputedLocks), 3, 10) },
    { id: 'trust_expiring_locks', type: 'expiring_lock', title: 'Expiring locks', count: countValue(expiringLocks), severity: severityForCount(countValue(expiringLocks), 5, 20) },
    { id: 'trust_proofs_pending', type: 'proof_pending', title: 'Proofs pending', count: countValue(proofsPending), severity: severityForCount(countValue(proofsPending), 5, 20) },
    { id: 'trust_payouts_pending', type: 'brokerage_eligibility', title: 'Brokerage eligibility pending', count: countValue(payoutsPending), severity: severityForCount(countValue(payoutsPending), 5, 20) },
  ]

  return rows
    .filter((row) => row.count > 0)
    .map((row) => ({
      id: row.id,
      type: row.type,
      severity: row.severity,
      title: row.title,
      safe_ref: `trust:${row.type}`,
      action: 'open_broker_locks',
      route: 'broker_locks',
      metrics: { count: row.count },
      created_at: nowIso,
    }))
}

async function getRiskSummary(admin: Admin) {
  const [riskResult, abuseResult] = await Promise.all([
    admin.from('risk_notifications').select('id, severity, notification_type, reason_code, created_at').in('status', OPEN_RISK_STATUSES).order('created_at', { ascending: false }).limit(8),
    admin.from('abuse_events').select('id, severity, event_type, status, created_at').in('status', OPEN_ABUSE_STATUSES).order('created_at', { ascending: false }).limit(8),
  ])

  if (riskResult.error || abuseResult.error) throw new Error('dashboard_read_failed')

  const risks = (riskResult.data ?? []).map((row: any) => ({
    id: row.id,
    type: safeText(row.reason_code) || 'risk_alert',
    severity: safeText(row.severity) || 'medium',
    title: safeText(row.notification_type, 80) || 'Risk notification',
    safe_ref: safeRef('risk', row.id),
    action: 'review_risk',
    route: 'risk_center',
    metrics: {},
    created_at: row.created_at,
  }))

  const abuse = (abuseResult.data ?? []).map((row: any) => ({
    id: row.id,
    type: safeText(row.event_type) || 'abuse_event',
    severity: safeText(row.severity) || 'medium',
    title: safeText(row.event_type, 80) || 'Abuse event',
    safe_ref: safeRef('abuse', row.id),
    action: 'review_risk',
    route: 'risk_center',
    metrics: {},
    created_at: row.created_at,
  }))

  return risks.concat(abuse).slice(0, 10)
}

async function getAuditTimeline(admin: Admin) {
  const { data: auditRows, error } = await admin
    .from('audit_events')
    .select('id, actor_id, event_type, lead_id, created_at')
    .order('created_at', { ascending: false })
    .limit(8)

  if (error) throw new Error('dashboard_read_failed')

  const roleByActor = await actorRoleMap(
    admin,
    (auditRows ?? []).map((row: any) => safeId(row.actor_id)).filter(Boolean),
  )
  const orgByLead = await auditLeadOrgMap(
    admin,
    (auditRows ?? []).map((row: any) => safeId(row.lead_id)).filter(Boolean),
  )

  return (auditRows ?? []).map((row: any) => ({
    id: row.id,
    event_type: safeText(row.event_type),
    actor_role: roleByActor.get(row.actor_id) ?? 'unknown',
    organization_id: orgByLead.get(row.lead_id) ?? null,
    created_at: row.created_at,
  }))
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (!['GET', 'POST'].includes(req.method)) return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()
    const context = await requirePlatformAdmin(admin, user.id)
    if (!context) return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)

    const actions = await getAllowedActions(admin, user.id, context)
    if (!actions.includes('view_super_admin_dashboard')) {
      return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)
    }

    const now = new Date()
    const nowIso = now.toISOString()
    const today = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate())).toISOString()
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000).toISOString()
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString()

    const [
      platformHealth,
      organizations,
      projects,
      workforce,
      attentionQueue,
      workflowBottlenecks,
      trustOperations,
      riskAlerts,
      auditEvents,
      totalOrganizations,
      activeProjects,
      activeBrokers,
      activeCallers,
      activeSms,
      leadsToday,
      verifiedVisitsToday,
      activeBrokerLocks,
      openRisks,
    ] = await Promise.all([
      getPlatformHealthSnapshot(admin, oneHourAgo),
      getOrganizationSummary(admin),
      getProjectSummary(admin),
      getWorkforcePerformance(admin, today),
      getAttentionQueue(admin),
      getWorkflowBottlenecks(admin, nowIso, oneDayAgo),
      getTrustOperations(admin, nowIso),
      getRiskSummary(admin),
      getAuditTimeline(admin),
      admin.from('organizations').select('id', { count: 'exact', head: true }),
      admin.from('projects').select('id', { count: 'exact', head: true }).eq('status', 'active'),
      admin.from('brokers_public').select('id', { count: 'exact', head: true }).eq('status', 'active'),
      admin.from('pilot_users').select('id', { count: 'exact', head: true }).eq('status', 'active').eq('role', 'caller'),
      admin.from('pilot_users').select('id', { count: 'exact', head: true }).eq('status', 'active').eq('role', 'sourcing_manager'),
      admin.from('leads_public').select('id', { count: 'exact', head: true }).gte('created_at', today),
      admin.from('site_visits').select('id', { count: 'exact', head: true }).gte('created_at', today).in('status', ['verified', 'completed']),
      admin.from('broker_locks').select('id', { count: 'exact', head: true }).eq('status', 'active'),
      admin.from('risk_notifications').select('id', { count: 'exact', head: true }).in('status', OPEN_RISK_STATUSES),
    ])

    const workflowSummary = await getWorkflowSummary(admin, today, workflowBottlenecks)

    await recordAudit(admin, user.id, context.organizationId, 'super_admin_dashboard_viewed', {
      allowed_actions: actions,
      generated_at: nowIso,
    })

    const kpis = {
      organizations: countValue(totalOrganizations),
      active_projects: countValue(activeProjects),
      active_brokers: countValue(activeBrokers),
      active_callers: countValue(activeCallers),
      active_sms: countValue(activeSms),
      leads_today: countValue(leadsToday),
      verified_visits_today: countValue(verifiedVisitsToday),
      active_broker_locks: countValue(activeBrokerLocks),
      open_risks: countValue(openRisks),
      total_organizations: countValue(totalOrganizations),
      total_brokers: countValue(activeBrokers),
      total_leads: countValue(leadsToday),
      calls_attempted: workflowSummary.secure_calls_today,
      scheduled_visits: workflowSummary.site_visits_today,
      verified_visits: countValue(verifiedVisitsToday),
      active_locks: countValue(activeBrokerLocks),
      open_disputes: trustOperations.find((row: any) => row.id === 'trust_disputed_locks')?.metrics?.count ?? 0,
      open_risk_alerts: countValue(openRisks),
      held_sync_reviews: workflowBottlenecks.find((row: any) => row.id === 'bottleneck_stuck_visits')?.metrics?.count ?? 0,
      active_users: countValue(activeCallers) + countValue(activeSms),
    }

    return safeJson({
      ok: true,
      generated_at: nowIso,
      platform_health: platformHealth,
      health: {
        status: platformHealth.status,
        last_event: platformHealth.last_event,
        critical_failures_1h: platformHealth.failed_functions,
      },
      kpis,
      attention_queue: attentionQueue,
      workforce,
      organizations,
      projects,
      workflow_summary: workflowSummary,
      workflow_bottlenecks: workflowBottlenecks,
      trust_operations: trustOperations,
      risk_alerts: riskAlerts,
      audit_events: auditEvents,
      allowed_actions: actions,
    })
  } catch (err) {
    const reason = err instanceof Error && err.message === 'dashboard_read_failed'
      ? 'dashboard_read_failed'
      : 'internal_server_error'
    return safeJson({ ok: false, reason }, 500)
  }
})
