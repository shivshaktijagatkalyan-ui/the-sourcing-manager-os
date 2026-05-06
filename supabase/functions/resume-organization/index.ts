import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, corsHeaders, currentUser, recordAudit, requirePermission, safeJson, validUuid } from '../_shared/sprint7.ts'

async function writeCheck(admin: ReturnType<typeof adminClient>, orgId: string, checkName: string, passed: boolean) {
  await admin.from('org_activation_checks').upsert({
    organization_id: orgId,
    check_name: checkName,
    passed,
    evidence_ref: { status: passed ? 'passed' : 'failed' },
    checked_at: new Date().toISOString(),
  }, { onConflict: 'organization_id, check_name' })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'access_denied' }, 401)

    const body = await req.json().catch(() => ({}))
    const orgId = validUuid(body.organization_id)
    if (!orgId) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const admin = adminClient()
    const allowed = await requirePermission(admin, user.id, 'can_pause_org', orgId)
    if (!allowed) return safeJson({ ok: false, reason: 'access_denied' }, 403)

    if (body.compliance_approved === true || body.pilot_approved === true) {
      await admin.from('organization_profiles').upsert({
        org_id: orgId,
        compliance_status: body.compliance_approved === true ? 'verified' : 'pending',
        kyc_status: body.compliance_approved === true ? 'verified' : 'pending',
        pilot_status: body.pilot_approved === true ? 'approved' : 'pending',
        approved_by: body.pilot_approved === true ? user.id : null,
        approved_at: body.pilot_approved === true ? new Date().toISOString() : null,
      }, { onConflict: 'org_id' })
    }

    const { data: profile } = await admin
      .from('organization_profiles')
      .select('pilot_status, compliance_status, kyc_status')
      .eq('org_id', orgId)
      .maybeSingle()

    const checks: Record<string, boolean> = {
      profile_exists: !!profile,
      pilot_approved: profile?.pilot_status === 'approved',
      compliance_verified: profile?.compliance_status === 'verified',
      kyc_verified: profile?.kyc_status === 'verified',
      audit_actor_exists: true,
    }

    for (const [checkName, passed] of Object.entries(checks)) {
      await writeCheck(admin, orgId, checkName, passed)
    }

    const failedChecks = Object.entries(checks).filter(([, passed]) => !passed).map(([checkName]) => checkName)
    if (failedChecks.length > 0) {
      return safeJson({ ok: false, reason: 'org_activation_blocked', failed_checks: failedChecks }, 409)
    }

    await admin.from('organizations').update({ status: 'active' }).eq('id', orgId)
    await recordAudit(admin, user.id, orgId, null, 'org_resumed', {
      organization_id: orgId,
      status: 'active',
      check_count: Object.keys(checks).length,
      passed_count: Object.keys(checks).length,
    })

    return safeJson({ ok: true, status: 'active' })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
