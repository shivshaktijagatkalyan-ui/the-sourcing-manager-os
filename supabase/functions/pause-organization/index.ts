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
    if (!orgId) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const admin = adminClient()
    const allowed = await requirePermission(admin, user.id, 'can_pause_org', orgId)
    if (!allowed) return safeJson({ ok: false, reason: 'access_denied' }, 403)

    await admin.from('organizations').update({ status: 'paused' }).eq('id', orgId)
    await recordAudit(admin, user.id, orgId, null, 'org_paused', { organization_id: orgId, status: 'paused' })

    return safeJson({ ok: true, status: 'paused' })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
