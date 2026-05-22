// @ts-ignore: Deno import
import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, corsHeaders, validUuid } from '../_shared/sprint7.ts'

declare const Deno: any;

const reviewableStatuses = new Set([
  'broker_review_pending',
  'photo_verified',
  'visit_done',
  'completed',
])

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
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
    const allowed = await requirePermission(admin, user.id, 'can_review_site_visits', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const { site_visit_id, action, reason } = await req.json()
    const siteVisitId = validUuid(site_visit_id)
    if (!siteVisitId) return safeJson({ ok: false, reason: 'invalid_site_visit' }, 400)

    if (!['approve', 'reject'].includes(action)) {
      return safeJson({ ok: false, reason: 'invalid_input' }, 400)
    }

    // 3. Fetch Visit
    const { data: visit, error: fetchError } = await admin
      .from('site_visits')
      .select('id, organization_id, status')
      .eq('id', siteVisitId)
      .eq('organization_id', pilot.org_id)
      .maybeSingle()

    if (fetchError || !visit || !reviewableStatuses.has(visit.status)) {
      return safeJson({ ok: false, reason: 'invalid_state' }, 409)
    }

    // 4. Atomic Secure Update
    const { data: result, error: updateError } = await admin.rpc('broker_review_site_visit_v2', {
        p_visit_id: siteVisitId,
        p_actor_id: user.id,
        p_action: action,
        p_reason: reason
    })

    if (updateError || !result || !result.ok) {
      return safeJson({ ok: false, reason: 'update_failed' }, 500)
    }

    return safeJson({ ok: true })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
