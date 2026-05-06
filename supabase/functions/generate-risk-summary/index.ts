// @ts-ignore: Deno import
import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, corsHeaders } from '../_shared/sprint7.ts'



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
    const allowed = await requirePermission(admin, user.id, 'can_generate_risk_summaries', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const today = new Date().toISOString().slice(0, 10)

    // 3. Aggregate Data
    const [{ data: members }, { data: events }, { data: disputes }, { data: visits }, { data: locks }] = await Promise.all([
      admin.from('pilot_users').select('user_id,status').eq('org_id', pilot.org_id),
      admin.from('abuse_events').select('event_type,severity,status').eq('organization_id', pilot.org_id).gte('created_at', `${today}T00:00:00.000Z`),
      admin.from('disputes').select('status').eq('org_id', pilot.org_id),
      admin.from('site_visits').select('status, sourcing_manager_id, broker_id'),
      admin.from('broker_locks').select('id, broker_id, created_at').gte('created_at', `${today}T00:00:00.000Z`),
    ])

    const orgUsers = new Set((members ?? []).map((m: any) => m.user_id))
    const orgVisits = (visits ?? []).filter((v: any) => orgUsers.has(v.sourcing_manager_id) || orgUsers.has(v.broker_id))
    const dailyEvents = events ?? []

    const row = {
      organization_id: pilot.org_id,
      activity_date: today,
      active_users_count: (members ?? []).filter((m: any) => m.status === 'active').length,
      disabled_users_count: (members ?? []).filter((m: any) => m.status === 'disabled').length,
      site_visits_started: orgVisits.filter((v: any) => ['started', 'gps_verified', 'photo_verified', 'broker_review_pending', 'completed'].includes(v.status)).length,
      site_visits_verified: orgVisits.filter((v: any) => v.status === 'completed').length,
      gps_failures: dailyEvents.filter((e: any) => ['gps_outside_geofence_repeated', 'gps_accuracy_failure_repeated'].includes(String(e.event_type))).length,
      abuse_events_count: dailyEvents.length,
      critical_events_count: dailyEvents.filter((e: any) => e.severity === 'critical').length,
      open_disputes_count: (disputes ?? []).filter((d: any) => !['closed', 'rejected'].includes(d.status)).length,
      locks_created_count: (locks ?? []).filter((l: any) => orgUsers.has(l.broker_id)).length,
    }

    // 4. Upsert Summary
    const { error } = await admin
      .from('pilot_activity_daily')
      .upsert(row, { onConflict: 'organization_id, activity_date' })

    if (error) throw new Error('summary_upsert_failed')

    await recordAudit(admin, user.id, pilot.org_id, null, 'risk_summary_generated', { activity_date: today })

    return safeJson({ ok: true, summary: row })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})

