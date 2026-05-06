import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, corsHeaders, currentUser, legacyRole, recordAudit, requirePermission, safeJson, validUuid } from '../_shared/sprint7.ts'

async function writeCheck(admin: ReturnType<typeof adminClient>, orgId: string, userId: string, checkName: string, passed: boolean) {
  await admin.from('user_activation_checks').upsert({
    organization_id: orgId,
    user_id: userId,
    check_name: checkName,
    passed,
    evidence_ref: { status: passed ? 'passed' : 'failed' },
    checked_at: new Date().toISOString(),
  }, { onConflict: 'organization_id, user_id, check_name' })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'access_denied' }, 401)

    const body = await req.json().catch(() => ({}))
    const orgId = validUuid(body.organization_id)
    const targetUserId = validUuid(body.target_user_id)
    if (!orgId || !targetUserId) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const admin = adminClient()
    const allowed = await requirePermission(admin, user.id, 'can_manage_org_users', orgId)
    if (!allowed) return safeJson({ ok: false, reason: 'access_denied' }, 403)

    if (body.profile_completed === true || body.compliance_approved === true || body.pilot_approved === true) {
      await admin.from('user_profiles').upsert({
        user_id: targetUserId,
        profile_completed: body.profile_completed === true,
        compliance_status: body.compliance_approved === true ? 'verified' : 'pending',
        pilot_status: body.pilot_approved === true ? 'approved' : 'pending',
      }, { onConflict: 'user_id' })
    }

    const [{ data: org }, { data: orgProfile }, { data: profile }, { data: role }, { data: suspended }] = await Promise.all([
      admin.from('organizations').select('status').eq('id', orgId).maybeSingle(),
      admin.from('organization_profiles').select('pilot_status, compliance_status').eq('org_id', orgId).maybeSingle(),
      admin.from('user_profiles').select('profile_completed, pilot_status, compliance_status').eq('user_id', targetUserId).maybeSingle(),
      admin.from('role_assignments').select('role_id, permission_template_id, permission_templates(status)').eq('organization_id', orgId).eq('user_id', targetUserId).eq('status', 'active').maybeSingle(),
      admin.rpc('has_active_suspension', { p_user_id: targetUserId }),
    ])

    const checks: Record<string, boolean> = {
      organization_active: org?.status === 'active',
      organization_pilot_approved: orgProfile?.pilot_status === 'approved',
      organization_compliance_verified: orgProfile?.compliance_status === 'verified',
      role_assigned: !!role?.role_id,
      permission_template_attached: !!role?.permission_template_id && role?.permission_templates?.status === 'active',
      profile_complete: profile?.profile_completed === true,
      user_pilot_approved: profile?.pilot_status === 'approved',
      user_compliance_verified: profile?.compliance_status === 'verified',
      no_active_suspension: suspended !== true,
      audit_actor_exists: true,
    }

    for (const [checkName, passed] of Object.entries(checks)) {
      await writeCheck(admin, orgId, targetUserId, checkName, passed)
    }

    const failedChecks = Object.entries(checks).filter(([, passed]) => !passed).map(([checkName]) => checkName)
    if (failedChecks.length > 0) {
      return safeJson({ ok: false, reason: 'activation_blocked', failed_checks: failedChecks }, 409)
    }

    await admin.from('pilot_users').upsert({
      user_id: targetUserId,
      org_id: orgId,
      role: legacyRole(role.role_id),
      status: 'active',
    }, { onConflict: 'user_id, org_id' })

    await recordAudit(admin, user.id, orgId, targetUserId, 'user_activated', {
      organization_id: orgId,
      target_user_id: targetUserId,
      role_id: role.role_id,
      check_count: Object.keys(checks).length,
      passed_count: Object.keys(checks).length,
    })

    return safeJson({ ok: true, status: 'active' })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
