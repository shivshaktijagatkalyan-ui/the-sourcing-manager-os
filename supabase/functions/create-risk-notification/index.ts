import { adminClient, currentUser, requirePermission, safeJson, recordAudit, validUuid } from '../_shared/sprint7.ts'

const types = new Set([
  'critical_abuse_event',
  'duplicate_lock_conflict',
  'gps_rejection_repeated',
  'broker_rejection_spike',
  'org_paused',
  'dispute_opened',
  'dispute_escalated',
  'trust_decay_run',
])

const severities = new Set(['low', 'medium', 'high', 'critical'])

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()

    // 1. Fetch Pilot Context
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status, organizations(status)')
      .eq('user_id', user.id)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    // 2. Strict Permission Check
    const allowed = await requirePermission(admin, user.id, 'can_view_risk_dashboard', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const body = await req.json().catch(() => ({}))
    const notificationType = typeof body.notification_type === 'string' ? body.notification_type : ''
    const severity = typeof body.severity === 'string' ? body.severity : ''
    const reasonCode = typeof body.reason_code === 'string' ? body.reason_code.trim() : ''
    if (!types.has(notificationType) || !severities.has(severity) || !reasonCode) {
      return safeJson({ ok: false, reason: 'invalid_input' }, 400)
    }

    const abuseEventId = validUuid(body.abuse_event_id)
    const recipientUserId = validUuid(body.recipient_user_id)
    if (recipientUserId) {
      const { data: recipientInOrg } = await admin
        .from('pilot_users')
        .select('user_id')
        .eq('user_id', recipientUserId)
        .eq('org_id', pilot.org_id)
        .maybeSingle()
      if (!recipientInOrg) return safeJson({ ok: false, reason: 'invalid_scope' }, 403)
    }

    const { data, error } = await admin
      .from('risk_notifications')
      .insert({
        abuse_event_id: abuseEventId,
        organization_id: pilot.org_id,
        recipient_user_id: recipientUserId,
        notification_type: notificationType,
        severity,
        reason_code: reasonCode,
      })
      .select('id')
      .single()

    if (error || !data) return safeJson({ ok: false, reason: 'notification_failed' }, 500)

    await recordAudit(admin, user.id, pilot.org_id, null, 'risk_notification_created', { 
      notification_id: data.id, 
      notification_type: notificationType, 
      severity 
    })

    return safeJson({ ok: true, notification_id: data.id })
  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
