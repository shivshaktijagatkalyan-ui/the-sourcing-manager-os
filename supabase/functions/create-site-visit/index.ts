// @ts-ignore: Deno import
import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, corsHeaders } from '../_shared/sprint7.ts'



serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()

    // 1. Fetch Pilot Context for Org ID
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status, organizations(status)')
      .eq('user_id', user.id)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    // 2. Strict Permission Check
    const allowed = await requirePermission(admin, user.id, 'can_create_site_visits', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const { lead_id, project_id, scheduled_at } = await req.json()

    // 3. Validate Ownership & Active Loan
    const { data: lead, error: leadError } = await admin
      .from('leads_public')
      .select('broker_id, organization_id')
      .eq('id', lead_id)
      .single()

    if (leadError || !lead || lead.organization_id !== pilot.org_id) {
      return safeJson({ ok: false, reason: 'lead_not_found_or_forbidden' }, 404)
    }

    const { data: hasLoan } = await admin.rpc('has_active_data_loan', {
      p_lead_id: lead_id,
      p_user_id: user.id,
      p_purpose: 'site_visit'
    })

    if (!hasLoan) return safeJson({ ok: false, reason: 'active_loan_required' }, 403)

    // 4. Create record
    const { data: visit, error: visitError } = await admin
      .from('site_visits')
      .insert({
        lead_id,
        broker_id: lead.broker_id,
        sourcing_manager_id: user.id,
        project_id,
        status: 'scheduled',
        scheduled_at: scheduled_at || new Date().toISOString()
      })
      .select()
      .single()

    if (visitError) throw new Error('visit_creation_failed')

    // 5. Audit
    await recordAudit(admin, user.id, pilot.org_id, null, 'site_visit_created', {
      site_visit_id: visit.id,
      lead_id,
      project_id
    })

    return safeJson({ ok: true, visit_id: visit.id })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
