import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, validUuid } from '../_shared/sprint7.ts'

serve(async (req: Request) => {
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

    const body = await req.json()
    const notificationId = validUuid(body.notification_id)
    if (!notificationId) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const { data: existing, error: readError } = await admin
      .from('risk_notifications')
      .select('id, organization_id, recipient_user_id, notification_type')
      .eq('id', notificationId)
      .maybeSingle()

    if (readError || !existing) return safeJson({ ok: false, reason: 'not_found' }, 404)
    
    const isRecipient = existing.recipient_user_id === user.id
    if (!isRecipient && existing.organization_id !== pilot.org_id) {
      return safeJson({ ok: false, reason: 'forbidden_org_mismatch' }, 403)
    }

    const { error } = await admin
      .from('risk_notifications')
      .update({
        status: 'acknowledged',
        acknowledged_at: new Date().toISOString(),
        acknowledged_by: user.id,
      })
      .eq('id', notificationId)
      .in('status', ['unread', 'acknowledged'])

    if (error) return safeJson({ ok: false, reason: 'ack_failed' }, 500)

    await recordAudit(admin, user.id, pilot.org_id, null, 'risk_notification_acknowledged', { 
      notification_id: notificationId, 
      notification_type: existing.notification_type 
    })

    return safeJson({ ok: true })
  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
