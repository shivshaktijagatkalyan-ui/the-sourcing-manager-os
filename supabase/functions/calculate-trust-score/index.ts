import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson } from '../_shared/sprint7.ts'

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()

    // 1. Fetch Pilot Context
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status')
      .eq('user_id', user.id)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked' }, 403)
    }

    // 2. Strict Permission Check
    const allowed = await requirePermission(admin, user.id, 'can_view_audit_logs', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden' }, 403)

    const { entity_id, entity_type } = await req.json()

    if (!entity_id || !entity_type) {
      return safeJson({ ok: false, reason: 'invalid_input' }, 400)
    }

    // 3. Fetch Audit Events
    const { data: events, error: eventError } = await admin
      .from('audit_events')
      .select('event_type, event_context')
      .eq('actor_id', entity_id)

    if (eventError) throw new Error('event_fetch_failed')

    // 4. Scoring Model
    let score = 3.0; // Start at neutral
    const components = {
        positive_events: 0,
        negative_events: 0,
        total_events: events.length
    }

    events.forEach((event: any) => {
        if (event.event_type === 'site_visit_state_change') {
            const ns = event.event_context.new_status
            if (ns === 'completed' || ns === 'gps_verified' || ns === 'photo_verified') {
                score += 0.05
                components.positive_events++
            } else if (ns === 'invalid') {
                score -= 0.5
                components.negative_events++
            }
        }
        if (event.event_type === 'gps_verified') {
             score += 0.05
             components.positive_events++
        }
        if (event.event_type === 'gps_rejected') {
             score -= 0.2
             components.negative_events++
        }
    })

    score = Math.max(0, Math.min(5, score))

    // 5. Upsert Trust Score
    const { error: updateError } = await admin
      .from('trust_scores')
      .upsert({
          entity_id,
          entity_type,
          score: parseFloat(score.toFixed(2)),
          components_json: components,
          last_updated_at: new Date().toISOString()
      }, { onConflict: 'entity_id, entity_type' })

    if (updateError) throw new Error('upsert_failed')

    return safeJson({ ok: true, score: score.toFixed(2) })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
