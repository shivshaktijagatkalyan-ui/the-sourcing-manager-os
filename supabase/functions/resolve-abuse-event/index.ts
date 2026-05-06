import { adminClient, currentUser, requirePermission, safeJson, recordAudit, validUuid } from '../_shared/sprint7.ts'

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
    const allowed = await requirePermission(admin, user.id, 'can_resolve_abuse', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const body = await req.json()
    const eventId = validUuid(body.abuse_event_id)
    const status = body.status === 'dismissed' ? 'dismissed' : 'resolved'
    if (!eventId) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    // 3. Atomic Resolve
    const { data: updated, error } = await admin
      .from('abuse_events')
      .update({ status, resolved_at: new Date().toISOString(), resolved_by: user.id })
      .eq('id', eventId)
      .eq('organization_id', pilot.org_id)
      .in('status', ['open', 'investigating'])
      .select('id, lead_id, event_type')
      .maybeSingle()

    if (error || !updated) throw new Error('resolve_failed')

    await recordAudit(admin, user.id, pilot.org_id, updated.lead_id, 'abuse_event_resolved', { 
        abuse_event_id: updated.id, 
        event_type: updated.event_type, 
        status 
    })

    return safeJson({ ok: true, status })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})

