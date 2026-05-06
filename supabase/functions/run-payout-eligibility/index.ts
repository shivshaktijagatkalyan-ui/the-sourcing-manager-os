import { adminClient, currentUser, requirePermission, safeJson, recordAudit } from '../_shared/sprint7.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
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
    const allowed = await requirePermission(admin, user.id, 'can_manage_payouts', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const today = new Date().toISOString().split('T')[0]
    const runId = crypto.randomUUID()

    // 3. Fetch pending payouts for THIS org
    const { data: payouts, error: fetchError } = await admin
      .from('payout_ledger')
      .select('id, broker_id, broker_lock_id')
      .eq('organization_id', pilot.org_id)
      .eq('status', 'pending')
      .lte('eligibility_date', today)

    if (fetchError) throw new Error('fetch_payouts_failed')

    let eligibleCount = 0
    let rejectedCount = 0

    for (const payout of payouts ?? []) {
      // 4. Verify Lock Status
      const { data: lock } = await admin
        .from('broker_locks')
        .select('status')
        .eq('id', payout.broker_lock_id)
        .single()

      if (lock?.status !== 'active') {
        await admin.from('payout_ledger').update({ status: 'rejected', metadata: { reason: 'lock_inactive' } }).eq('id', payout.id)
        rejectedCount++
        continue
      }

      // 5. Verify Trust Score
      const { data: trust } = await admin
        .from('trust_scores')
        .select('score')
        .eq('entity_id', payout.broker_id)
        .eq('entity_type', 'user')
        .maybeSingle()

      const score = trust?.score ?? 0
      if (score < 3.0) {
        await admin.from('payout_ledger').update({ status: 'rejected', metadata: { reason: 'insufficient_trust', score } }).eq('id', payout.id)
        rejectedCount++
        continue
      }

      // 6. Mark as Eligible
      await admin.from('payout_ledger').update({ status: 'eligible', metadata: { processed_run_id: runId } }).eq('id', payout.id)
      eligibleCount++
    }

    await recordAudit(admin, user.id, pilot.org_id, null, 'payout_eligibility_run', { 
        run_id: runId, 
        eligible_count: eligibleCount, 
        rejected_count: rejectedCount 
    })

    return safeJson({ ok: true, eligible_count: eligibleCount, rejected_count: rejectedCount, run_id: runId })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})

