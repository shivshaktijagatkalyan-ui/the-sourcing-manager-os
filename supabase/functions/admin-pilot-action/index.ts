import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, roles, legacyRole, defaultTemplateForRole, validUuid, corsHeaders } from '../_shared/sprint7.ts'

declare const Deno: any;

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()
    const { action, payload } = await req.json()

    if (action === 'create_organization') {
      const { data: platformRole, error: platformRoleError } = await admin
        .from('role_assignments')
        .select('id')
        .eq('user_id', user.id)
        .eq('role_id', 'platform_admin')
        .eq('status', 'active')
        .maybeSingle()

      const allowed = await requirePermission(admin, user.id, 'can_manage_org_users')
      if (platformRoleError || !platformRole || !allowed) {
        return safeJson({ ok: false, reason: 'forbidden' }, 403)
      }

      const { name } = payload
      if (!name) return safeJson({ ok: false, reason: 'name_required' }, 400)

      const { data, error } = await admin
        .from('organizations')
        .insert({ name, status: 'active' })
        .select()
        .single()

      if (error) throw new Error('org_creation_failed')

      await recordAudit(admin, user.id, data.id, null, 'organization_created', { name })

      return safeJson({ ok: true, organization: data })
    }

    if (action === 'update_organization_status') {
      const { org_id, status } = payload
      if (!org_id || !status) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

      const allowed = await requirePermission(admin, user.id, 'can_pause_org', org_id)
      if (!allowed) return safeJson({ ok: false, reason: 'forbidden' }, 403)

      const { data, error } = await admin
        .from('organizations')
        .update({ status })
        .eq('id', org_id)
        .select()
        .single()

      if (error) throw new Error('org_update_failed')

      const auditEvent = status === 'paused' ? 'org_paused' : 'org_resumed'
      await recordAudit(admin, user.id, org_id, null, auditEvent, { status })

      return safeJson({ ok: true, organization: data })
    }

    if (action === 'set_user_role') {
        const { target_user_id, target_org_id, role, status } = payload
        const orgId = validUuid(target_org_id)
        const targetUserId = validUuid(target_user_id)

        if (!orgId || !targetUserId || !roles.has(role)) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

        const allowed = await requirePermission(admin, user.id, 'can_manage_org_users', orgId)
        if (!allowed) return safeJson({ ok: false, reason: 'forbidden' }, 403)

        // Delegate to Sprint 7 assignment logic
        const templateId = await defaultTemplateForRole(admin, orgId, role, user.id)
        if (!templateId) return safeJson({ ok: false, reason: 'template_creation_failed' }, 500)

        // Deactivate old assignments
        await admin
            .from('role_assignments')
            .update({ status: 'inactive', revoked_at: new Date().toISOString(), revoked_by: user.id })
            .eq('organization_id', orgId)
            .eq('user_id', targetUserId)
            .eq('status', 'active')

        // Create new assignment
        const { error: assignError } = await admin.from('role_assignments').insert({
            organization_id: orgId,
            user_id: targetUserId,
            role_id: role,
            permission_template_id: templateId,
            assigned_by: user.id,
            status: 'active',
        })
        if (assignError) throw new Error('role_assignment_failed')

        // Sync legacy pilot_users table
        const { data: pilotUser, error: pilotError } = await admin
          .from('pilot_users')
          .upsert({
              user_id: targetUserId,
              org_id: orgId,
              role: legacyRole(role),
              status: status ?? 'active'
          }, { onConflict: 'user_id, org_id' })
          .select()
          .single()

        if (pilotError) throw new Error('pilot_user_sync_failed')

        await recordAudit(admin, user.id, orgId, targetUserId, 'role_assigned', { role, status })

        return safeJson({ ok: true, pilot_user: pilotUser })
    }

    return safeJson({ ok: false, reason: 'unknown_action' }, 400)

  } catch {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
