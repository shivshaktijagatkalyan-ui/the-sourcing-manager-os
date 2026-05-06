import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, cleanText, corsHeaders, currentUser, recordAudit, requirePermission, safeJson } from '../_shared/sprint7.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'access_denied' }, 401)

    const admin = adminClient()
    const allowed = await requirePermission(admin, user.id, 'can_manage_org_users')
    if (!allowed) return safeJson({ ok: false, reason: 'access_denied' }, 403)

    const body = await req.json().catch(() => ({}))
    const name = cleanText(body.organization_name ?? body.org_name, 140)
    if (name.length < 2) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const { data: org, error: orgError } = await admin
      .from('organizations')
      .insert({ name, status: 'paused' })
      .select('id')
      .single()

    if (orgError || !org) return safeJson({ ok: false, reason: 'create_failed' }, 500)

    await admin.from('organization_profiles').insert({
      org_id: org.id,
      legal_name: name,
      city: cleanText(body.city, 80) || null,
      state: cleanText(body.state, 80) || null,
      created_by: user.id,
    })

    await admin.from('onboarding_requests').insert({
      organization_id: org.id,
      requested_by: user.id,
      request_type: 'organization_onboarding',
      status: 'open',
      reason_code: 'org_created_paused',
    })

    await recordAudit(admin, user.id, org.id, null, 'organization_created', {
      organization_id: org.id,
      status: 'paused',
    })

    return safeJson({ ok: true, org_id: org.id, status: 'paused' })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
