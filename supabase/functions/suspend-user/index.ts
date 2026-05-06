import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, cleanText, corsHeaders, currentUser, recordAudit, requirePermission, safeJson, validUuid } from '../_shared/sprint7.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'access_denied' }, 401)

    const body = await req.json().catch(() => ({}))
    const orgId = validUuid(body.organization_id)
    const targetUserId = validUuid(body.target_user_id)
    const reasonCode = cleanText(body.reason_code ?? body.reason, 80) || 'operator_review'
    if (!orgId || !targetUserId) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const admin = adminClient()
    const allowed = await requirePermission(admin, user.id, 'can_suspend_user', orgId)
    if (!allowed) return safeJson({ ok: false, reason: 'access_denied' }, 403)

    const { data: target } = await admin
      .from('pilot_users')
      .select('user_id')
      .eq('user_id', targetUserId)
      .eq('org_id', orgId)
      .maybeSingle()
    if (!target) return safeJson({ ok: false, reason: 'invalid_scope' }, 403)

    const { error } = await admin.from('user_suspensions').insert({
      user_id: targetUserId,
      suspended_by: user.id,
      reason: reasonCode,
    })
    if (error) return safeJson({ ok: false, reason: 'suspend_failed' }, 500)

    await admin.from('pilot_users').update({ status: 'disabled' }).eq('user_id', targetUserId).eq('org_id', orgId)

    await recordAudit(admin, user.id, orgId, targetUserId, 'user_suspended', {
      organization_id: orgId,
      target_user_id: targetUserId,
      reason_code: reasonCode,
    })

    return safeJson({ ok: true, status: 'suspended' })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
