import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, cleanText, corsHeaders, currentUser, permissions, recordAudit, requirePermission, safeJson, validUuid } from '../_shared/sprint7.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'access_denied' }, 401)

    const body = await req.json().catch(() => ({}))
    const orgId = validUuid(body.organization_id)
    const templateId = validUuid(body.permission_template_id)
    const name = cleanText(body.name, 90)
    const requestedPermissions = Array.isArray(body.permissions) ? body.permissions.filter((item) => typeof item === 'string' && permissions.has(item)) : []
    if (!orgId || name.length < 2 || requestedPermissions.length === 0) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const admin = adminClient()
    const allowed = await requirePermission(admin, user.id, 'can_manage_org_users', orgId)
    if (!allowed) return safeJson({ ok: false, reason: 'access_denied' }, 403)

    let finalTemplateId = templateId
    if (finalTemplateId) {
      const { data: existing } = await admin
        .from('permission_templates')
        .select('id')
        .eq('id', finalTemplateId)
        .eq('organization_id', orgId)
        .maybeSingle()
      if (!existing) return safeJson({ ok: false, reason: 'invalid_scope' }, 403)

      await admin.from('permission_templates').update({ name, updated_by: user.id }).eq('id', finalTemplateId)
      await admin.from('permission_template_permissions').delete().eq('template_id', finalTemplateId)
    } else {
      const { data: created, error } = await admin
        .from('permission_templates')
        .insert({ organization_id: orgId, name, created_by: user.id, updated_by: user.id })
        .select('id')
        .single()
      if (error || !created) return safeJson({ ok: false, reason: 'template_failed' }, 500)
      finalTemplateId = created.id
    }

    await admin.from('permission_template_permissions').insert(
      requestedPermissions.map((permission) => ({ template_id: finalTemplateId, permission_id: permission })),
    )

    await recordAudit(admin, user.id, orgId, null, 'permission_template_updated', {
      organization_id: orgId,
      permission_template_id: finalTemplateId,
      check_count: requestedPermissions.length,
    })

    return safeJson({ ok: true, permission_template_id: finalTemplateId })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
