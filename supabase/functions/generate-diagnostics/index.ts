import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit } from '../_shared/sprint7.ts'

declare const Deno: any;

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })

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

    // Aggregate statistics (PII-Free)
    const [orgs, users, loans, calls, visits, payouts] = await Promise.all([
      admin.from('organizations').select('id', { count: 'exact', head: true }),
      admin.from('pilot_users').select('user_id', { count: 'exact', head: true }),
      admin.from('data_loans').select('id', { count: 'exact', head: true }),
      admin.from('call_attempts').select('id', { count: 'exact', head: true }),
      admin.from('site_visits').select('id', { count: 'exact', head: true }),
      admin.from('payout_ledger').select('id', { count: 'exact', head: true })
    ])

    const snapshot = {
      active_orgs: orgs.count,
      active_users: users.count,
      active_loans: loans.count,
      calls_queued: calls.count,
      site_visits_verified: visits.count,
      payout_entries: payouts.count,
      generated_at: new Date().toISOString()
    }

    // Record audit event
    await recordAudit(admin, user.id, pilot.org_id, null, 'diagnostics_snapshot_created', { stats: snapshot })

    return safeJson(snapshot)

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
