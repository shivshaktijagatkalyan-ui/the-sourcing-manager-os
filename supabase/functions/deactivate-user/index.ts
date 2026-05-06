import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, corsHeaders, currentUser, recordAudit, requirePermission, safeJson, validUuid } from '../_shared/sprint7.ts'

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

    await admin.from('pilot_users').update({ status: 'disabled' }).eq('org_id', orgId).eq('user_id', targetUserId)

    await recordAudit(admin, user.id, orgId, targetUserId, 'user_deactivated', {
      organization_id: orgId,
      target_user_id: targetUserId,
      status: 'disabled',
    })

    return safeJson({ ok: true, status: 'disabled' })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
