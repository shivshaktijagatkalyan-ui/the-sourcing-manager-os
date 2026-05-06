import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, corsHeaders, currentUser, defaultTemplateForRole, legacyRole, recordAudit, requirePermission, roles, safeJson, validUuid } from '../_shared/sprint7.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'access_denied' }, 401)

    const body = await req.json().catch(() => ({}))
    const orgId = validUuid(body.organization_id)
    const targetUserId = validUuid(body.target_user_id)
    const roleId = typeof body.role_id === 'string' ? body.role_id : ''
    let templateId = validUuid(body.permission_template_id)
    if (!orgId || !targetUserId || !roles.has(roleId)) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const admin = adminClient()
    const allowed = await requirePermission(admin, user.id, 'can_manage_org_users', orgId)
    if (!allowed) return safeJson({ ok: false, reason: 'access_denied' }, 403)

    const { data: pilot } = await admin
      .from('pilot_users')
      .select('user_id')
      .eq('user_id', targetUserId)
      .eq('org_id', orgId)
      .maybeSingle()
    if (!pilot) return safeJson({ ok: false, reason: 'invalid_scope' }, 403)

    if (templateId) {
      const { data: template } = await admin
        .from('permission_templates')
        .select('id')
        .eq('id', templateId)
        .eq('organization_id', orgId)
        .eq('status', 'active')
        .maybeSingle()
      if (!template) return safeJson({ ok: false, reason: 'invalid_template' }, 400)
    } else {
      templateId = await defaultTemplateForRole(admin, orgId, roleId, user.id)
      if (!templateId) return safeJson({ ok: false, reason: 'template_failed' }, 500)
    }

    await admin
      .from('role_assignments')
      .update({ status: 'inactive', revoked_at: new Date().toISOString(), revoked_by: user.id })
      .eq('organization_id', orgId)
      .eq('user_id', targetUserId)
      .eq('status', 'active')

    const { error } = await admin.from('role_assignments').insert({
      organization_id: orgId,
      user_id: targetUserId,
      role_id: roleId,
      permission_template_id: templateId,
      assigned_by: user.id,
      status: 'active',
    })
    if (error) return safeJson({ ok: false, reason: 'assign_failed' }, 500)

    await admin.from('pilot_users').upsert({
      user_id: targetUserId,
      org_id: orgId,
      role: legacyRole(roleId),
      status: 'disabled',
    }, { onConflict: 'user_id, org_id' })

    await recordAudit(admin, user.id, orgId, targetUserId, 'role_assigned', {
      organization_id: orgId,
      target_user_id: targetUserId,
      role_id: roleId,
      permission_template_id: templateId,
    })

    return safeJson({ ok: true, status: 'assigned' })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
