import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, validUuid } from '../_shared/sprint7.ts'

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()
    const { site_visit_id } = await req.json()
    const siteVisitId = validUuid(site_visit_id)

    if (!siteVisitId) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status, organizations(status)')
      .eq('user_id', user.id)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    const allowed = await requirePermission(admin, user.id, 'can_verify_site_visits', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    // 1. Fetch and validate visit (Using Service Role for consistent state check)
    const { data: visit, error: fetchError } = await admin
      .from('site_visits')
      .select('organization_id, sourcing_manager_id, status')
      .eq('id', siteVisitId)
      .single()

    if (fetchError || !visit) return safeJson({ ok: false, reason: 'site_visit_not_found' }, 404)

    if (visit.organization_id !== pilot.org_id) {
      return safeJson({ ok: false, reason: 'forbidden_org_mismatch' }, 403)
    }

    // Strict Assignment Validation
    if (visit.sourcing_manager_id !== user.id) {
      return safeJson({ ok: false, reason: 'forbidden_not_assigned' }, 403)
    }

    if (visit.status !== 'scheduled') {
      return safeJson({ ok: false, reason: 'invalid_state' }, 409)
    }

    // 2. Update status to started using Service Role
    const { error: updateError } = await admin
      .from('site_visits')
      .update({
        status: 'started',
        updated_at: new Date().toISOString()
      })
      .eq('id', siteVisitId)
      .eq('status', 'scheduled')

    if (updateError) throw new Error('update_failed')

    return safeJson({ ok: true })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
