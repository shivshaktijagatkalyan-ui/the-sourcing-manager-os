import { adminClient, currentUser, requirePermission, safeJson, recordAudit } from '../_shared/sprint7.ts'

function clampScore(value: number) {
  return Math.max(0, Math.min(5, Number(value.toFixed(2))))
}

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
    const allowed = await requirePermission(admin, user.id, 'can_run_trust_decay', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const body = await req.json().catch(() => ({}))
    const thresholdDays = typeof body.inactivity_days === 'number' && body.inactivity_days > 0 ? Math.min(365, body.inactivity_days) : 30
    const runId = crypto.randomUUID()

    // 3. Fetch Active Members
    const { data: members, error: memberError } = await admin
      .from('pilot_users')
      .select('user_id')
      .eq('org_id', pilot.org_id)
      .eq('status', 'active')

    if (memberError) throw new Error('member_read_failed')

    let changed = 0
    for (const member of members ?? []) {
      const { data: trustRow } = await admin
        .from('trust_scores')
        .select('score, components_json')
        .eq('entity_id', member.user_id)
        .eq('entity_type', 'user')
        .maybeSingle()

      const { data: lastEvent } = await admin
        .from('audit_events')
        .select('created_at')
        .eq('actor_id', member.user_id)
        .in('event_type', ['site_visit_state_change', 'broker_lock_created', 'call_queued'])
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()

      const daysInactive = lastEvent?.created_at
        ? Math.floor((Date.now() - new Date(lastEvent.created_at).getTime()) / 86400000)
        : thresholdDays + 1

      if (daysInactive < thresholdDays) continue

      const before = Number(trustRow?.score ?? 3)
      const delta = daysInactive > thresholdDays * 3 ? -0.15 : -0.05
      const after = clampScore(before + delta)
      const reasonCode = lastEvent?.created_at ? 'inactivity_decay' : 'no_verified_activity'
      const components = {
        ...(trustRow?.components_json ?? {}),
        last_verified_event_at: lastEvent?.created_at ?? null,
        days_inactive: daysInactive,
        decay_rule: reasonCode,
      }

      await admin.from('trust_scores').upsert({
        entity_id: member.user_id,
        entity_type: 'user',
        score: after,
        components_json: components,
        last_updated_at: new Date().toISOString(),
      }, { onConflict: 'entity_id, entity_type' })

      await admin.from('trust_score_snapshots').insert({
        entity_id: member.user_id,
        entity_type: 'user',
        organization_id: pilot.org_id,
        score_before: before,
        score_after: after,
        score_delta: Number((after - before).toFixed(2)),
        reason_code: reasonCode,
        components_json: components,
        calculation_run_id: runId,
      })

      changed += 1
    }

    await recordAudit(admin, user.id, pilot.org_id, null, 'trust_decay_run', { 
        calculation_run_id: runId, 
        changed_count: changed,
        threshold_days: thresholdDays
    })

    return safeJson({ ok: true, changed_count: changed, calculation_run_id: runId })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})

