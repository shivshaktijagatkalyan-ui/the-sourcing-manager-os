import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, validUuid } from '../_shared/sprint7.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()
    const { action, payload } = await req.json()

    // 1. Get User Org Context
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status')
      .eq('user_id', user.id)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active') {
      return safeJson({ ok: false, reason: 'pilot_user_inactive' }, 403)
    }

    if (action === 'open_dispute') {
      const allowed = await requirePermission(admin, user.id, 'can_view_disputes', pilot.org_id)
      if (!allowed) return safeJson({ ok: false, reason: 'forbidden' }, 403)

      const { target_id, target_type, type, comment } = payload

      const { data: dispute, error: dError } = await admin
        .from('disputes')
        .insert({
            org_id: pilot.org_id,
            target_id,
            target_type,
            type,
            status: 'opened'
        })
        .select()
        .single()

      if (dError) throw new Error('dispute_creation_failed')

      await admin.from('dispute_events').insert({
          dispute_id: dispute.id,
          actor_id: user.id,
          event_type: 'dispute_opened',
          comment
      })

      await recordAudit(admin, user.id, pilot.org_id, null, 'dispute_opened', { dispute_id: dispute.id, type })

      return safeJson({ ok: true, dispute_id: dispute.id })
    }

    if (action === 'add_event') {
        const { dispute_id, event_type, comment, evidence_refs } = payload

        const allowed = await requirePermission(admin, user.id, 'can_view_disputes', pilot.org_id)
        if (!allowed) return safeJson({ ok: false, reason: 'forbidden' }, 403)

        // Verify org ownership
        const { data: dispute, error: dError } = await admin
            .from('disputes')
            .select('org_id')
            .eq('id', dispute_id)
            .single()

        if (dError || dispute.org_id !== pilot.org_id) {
            return safeJson({ ok: false, reason: 'forbidden_dispute_access' }, 403)
        }

        const { data: event, error: eError } = await admin
            .from('dispute_events')
            .insert({
                dispute_id,
                actor_id: user.id,
                event_type,
                comment,
                evidence_refs
            })
            .select()
            .single()

        if (eError) throw new Error('event_creation_failed')

        return safeJson({ ok: true, event_id: event.id })
    }

    if (action === 'resolve_dispute') {
        const { dispute_id, resolution_status, comment } = payload

        const allowed = await requirePermission(admin, user.id, 'can_resolve_disputes', pilot.org_id)
        if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

        const { error: uError } = await admin
            .from('disputes')
            .update({ status: resolution_status, updated_at: new Date().toISOString() })
            .eq('id', dispute_id)
            .eq('org_id', pilot.org_id) // Ensure org scope

        if (uError) throw new Error('resolution_failed')

        await admin.from('dispute_events').insert({
            dispute_id,
            actor_id: user.id,
            event_type: 'dispute_resolved',
            comment
        })

        await recordAudit(admin, user.id, pilot.org_id, null, 'dispute_resolved', { dispute_id, status: resolution_status })

        return safeJson({ ok: true })
    }

    return safeJson({ ok: false, reason: 'unknown_action' }, 400)

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
