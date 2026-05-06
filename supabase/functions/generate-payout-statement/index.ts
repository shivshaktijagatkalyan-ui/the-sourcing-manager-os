import { adminClient, currentUser, requirePermission, safeJson, recordAudit, validUuid } from '../_shared/sprint7.ts'

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

    const body = await req.json()
    const brokerId = validUuid(body.broker_id)
    const month = Number(body.month)
    const year = Number(body.year)

    if (!brokerId || isNaN(month) || isNaN(year)) {
        return safeJson({ ok: false, reason: 'invalid_input' }, 400)
    }

    // 3. Verify Broker Scope
    const { data: brokerInOrg } = await admin
      .from('pilot_users')
      .select('user_id')
      .eq('user_id', brokerId)
      .eq('org_id', pilot.org_id)
      .maybeSingle()
    
    if (!brokerInOrg) return safeJson({ ok: false, reason: 'invalid_broker_scope' }, 403)

    // 4. Fetch Payouts
    const startDate = `${year}-${month.toString().padStart(2, '0')}-01`
    const endDate = new Date(year, month, 0).toISOString().split('T')[0]

    const { data: payouts, error: fetchError } = await admin
      .from('payout_ledger')
      .select('id, amount, currency, status, eligibility_date, broker_lock_id')
      .eq('broker_id', brokerId)
      .eq('organization_id', pilot.org_id)
      .gte('eligibility_date', startDate)
      .lte('eligibility_date', endDate)
      .in('status', ['paid', 'eligible'])

    if (fetchError) throw new Error('payout_fetch_failed')

    if (!payouts || payouts.length === 0) {
        return safeJson({ ok: false, reason: 'no_eligible_payouts_for_period' }, 404)
    }

    const totalAmount = payouts.reduce((sum: number, p: any) => sum + Number(p.amount), 0)

    // 5. Insert Statement Record
    const { data: statement, error: stmtError } = await admin
      .from('payout_statements')
      .insert({
          organization_id: pilot.org_id,
          broker_id: brokerId,
          statement_period_start: startDate,
          statement_period_end: endDate,
          total_amount: totalAmount,
          payout_count: payouts.length,
          status: 'generated',
          metadata: { payouts: payouts.map((p: any) => p.id) }
      })
      .select()
      .single()

    if (stmtError) throw new Error('statement_creation_failed')

    // 6. Record Audit
    await recordAudit(admin, user.id, pilot.org_id, brokerId, 'payout_statement_generated', { 
        statement_id: statement.id, 
        period: `${year}-${month}` 
    })

    return safeJson({ ok: true, statement_id: statement.id, total: totalAmount })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})

