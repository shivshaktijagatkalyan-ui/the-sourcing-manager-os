import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, safeJson } from '../_shared/sprint7.ts'

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()
    const { site_visit_id } = await req.json()

    if (!site_visit_id) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    // 1. Fetch and validate visit (Using Service Role for consistent state check)
    const { data: visit, error: fetchError } = await admin
      .from('site_visits')
      .select('sourcing_manager_id, status')
      .eq('id', site_visit_id)
      .single()

    if (fetchError || !visit) return safeJson({ ok: false, reason: 'site_visit_not_found' }, 404)

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
      .eq('id', site_visit_id)

    if (updateError) throw new Error('update_failed')

    return safeJson({ ok: true })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
