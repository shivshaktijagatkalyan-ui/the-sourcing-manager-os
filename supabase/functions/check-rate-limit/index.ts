import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, currentUser, safeJson } from '../_shared/sprint7.ts'

const ACTION_LIMITS: Record<string, number> = {
  'initiate_call': 5,
  'broker_upload_lead': 20,
  'create_site_visit': 10,
  'verify_site_gps': 30,
  'incident_action': 3,
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })

  try {
    const user = await currentUser(req)
    if (!user) {
      return safeJson({ ok: false, reason: 'unauthorized' }, 401)
    }

    const admin = adminClient()

    const { action, organization_id } = await req.json()

    if (!action) {
      return safeJson({ ok: false, reason: 'action_required' }, 400)
    }

    const orgQuery = admin
      .from('pilot_users')
      .select('org_id')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .limit(1)

    if (organization_id) orgQuery.eq('org_id', organization_id)

    const { data: pilotRows, error: pilotError } = await orgQuery
    if (pilotError || !pilotRows || pilotRows.length === 0) {
      return safeJson({ ok: false, reason: 'forbidden_org_mismatch' }, 403)
    }

    const actorOrgId = pilotRows[0].org_id

    // Use server-defined limits to prevent spoofing
    const limit_per_minute = ACTION_LIMITS[action] ?? 50 

    // 1. Count recent attempts
    const oneMinuteAgo = new Date(Date.now() - 60 * 1000).toISOString()
    
    const { count, error: countError } = await admin
      .from('rate_limit_events')
      .select('id', { count: 'exact', head: true })
      .eq('actor_id', user.id)
      .eq('action', action)
      .gte('blocked_at', oneMinuteAgo)

    if (countError) throw new Error('database_query_failed')

    if (count !== null && count >= limit_per_minute) {
        // Record blockage in audit
        await admin.from('audit_events').insert({
            actor_id: user.id,
            event_type: 'rate_limit_blocked',
            event_context: { action, count, limit: limit_per_minute, organization_id: actorOrgId }
        })
        return safeJson({ ok: false, reason: 'rate_limit_exceeded' }, 429)
    }

    // 2. Record this attempt
    await admin.from('rate_limit_events').insert({
        actor_id: user.id,
        organization_id: actorOrgId,
        action,
        limit_key: `${user.id}:${action}`
    })

    return safeJson({ ok: true })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
