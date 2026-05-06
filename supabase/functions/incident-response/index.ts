import { adminClient, currentUser, requirePermission, safeJson, recordAudit } from '../_shared/sprint7.ts'

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })

  try {
    const user = await currentUser(req)
    if (!user) {
      return safeJson({ ok: false, reason: 'unauthorized' }, 401)
    }

    const admin = adminClient()

    const body = await req.json().catch(() => ({}))
    const { action, organization_id } = body

    if (!organization_id) {
      return safeJson({ ok: false, reason: 'organization_required' }, 400)
    }

    // 1. Permission Gate: Requires can_pause_org or platform_admin level access
    const hasPermission = await requirePermission(admin, user.id, 'can_pause_org', organization_id)
    if (!hasPermission) {
      return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)
    }

    if (action === 'pause_org') {
      const { error } = await admin
        .from('organizations')
        .update({
          status: 'paused',
          metadata: {
            pause_reason_recorded: true,
            paused_at: new Date().toISOString(),
            paused_by: user.id
          }
        })
        .eq('id', organization_id)

      if (error) throw new Error('database_update_failed')
    } else if (action === 'revoke_all_loans') {
      const { data: orgUsers, error: orgUsersError } = await admin
        .from('pilot_users')
        .select('user_id')
        .eq('org_id', organization_id)
        .eq('status', 'active')

      if (orgUsersError) throw new Error('database_query_failed')

      const orgUserIds = (orgUsers ?? []).map((row: { user_id: string }) => row.user_id)
      if (orgUserIds.length === 0) {
        return safeJson({ ok: true, action_performed: action })
      }

      const { data: orgLeads, error: orgLeadsError } = await admin
        .from('leads_public')
        .select('id')
        .in('broker_id', orgUserIds)

      if (orgLeadsError) throw new Error('database_query_failed')

      const orgLeadIds = (orgLeads ?? []).map((row: { id: string }) => row.id)
      if (orgLeadIds.length === 0) {
        return safeJson({ ok: true, action_performed: action })
      }

      const query = admin
        .from('data_loans')
        .update({
          status: 'revoked',
          revoked_at: new Date().toISOString(),
          revoked_by: user.id
        })
        .eq('status', 'active')
        .in('lead_id', orgLeadIds)

      const { error } = await query
      if (error) throw new Error('database_update_failed')
    } else {
      return safeJson({ ok: false, reason: 'invalid_action' }, 400)
    }

    // 2. Record Critical Audit Event
    await recordAudit(
      admin,
      user.id,
      organization_id || null,
      null,
      'emergency_lockdown_triggered',
      { action, reason_recorded: true, severity: 'critical' }
    )

    // 3. Record Critical Abuse Event for telemetry
    // p_risk_delta is clamped to -1.0 to avoid table constraint issues and maintain trust scoring integrity
    await admin.rpc('record_pilot_abuse', {
        p_actor_id: user.id,
        p_event_type: 'emergency_lockdown_triggered',
        p_severity: 'critical',
        p_risk_delta: -1.0,
        p_evidence_ref: { action, reason_recorded: true }
    })

    return safeJson({ ok: true, action_performed: action })

  } catch {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
