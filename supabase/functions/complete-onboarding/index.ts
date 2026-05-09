import { serve } from 'std/http/server.ts'
import {
  adminClient,
  cleanText,
  corsHeaders,
  currentUser,
  defaultTemplateForRole,
  legacyRole,
  privateHash,
  recordAudit,
  roles,
  safeJson,
} from '../_shared/sprint7.ts'

const inviteRoles = new Set([
  'sourcing_manager',
  'broker_owner',
  'broker_agent',
  'caller',
])

const openSignupRoles = new Set([
  'sourcing_manager',
  'broker_owner',
  'broker_agent',
])

function displayAlias(userId: string) {
  return `user-${userId.slice(0, 8)}`
}

function brokerCode(company: string, userId: string) {
  const compact = company.toUpperCase().replace(/[^A-Z0-9]/g, '')
  const prefix = (compact || 'BRK').padEnd(3, 'X').slice(0, 3)
  return `BRK-${prefix}-${userId.slice(0, 4).toUpperCase()}`
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'access_denied' }, 401)

    const body = await req.json().catch(() => ({}))
    const requestedRole = cleanText(body.selected_role ?? body.role_id ?? body.role, 60)
    const fullName = cleanText(body.full_name, 120)
    const company = cleanText(body.company ?? body.company_name, 160)
    const area = cleanText(body.area, 120)
    const city = cleanText(body.city, 120)
    const projectInterest = cleanText(body.project_interest, 160)
    const inviteCode = cleanText(body.invite_code, 180)

    if (!roles.has(requestedRole) || !inviteRoles.has(requestedRole) || fullName.length < 2) {
      return safeJson({ ok: false, reason: 'invalid_input' }, 400)
    }

    const admin = adminClient()
    const requiresApproval = Deno.env.get('SIGNUP_REQUIRES_APPROVAL') === 'true'
    const autoApprove = !requiresApproval || Deno.env.get('AUTO_APPROVE_SIGNUPS') === 'true'
    const now = new Date().toISOString()

    let orgId: string | null = null
    let finalRole = requestedRole
    let onboardingStatus = autoApprove ? 'active' : 'pending_access'

    if (inviteCode.length >= 16) {
      const inviteTokenHash = await privateHash(inviteCode)
      const { data: invite } = await admin
        .from('organization_invites')
        .select('id, organization_id, target_role, status, expires_at')
        .eq('invite_token_hash', inviteTokenHash)
        .eq('status', 'pending')
        .maybeSingle()

      if (!invite || new Date(invite.expires_at).getTime() <= Date.now()) {
        return safeJson({ ok: false, reason: 'invite_invalid' }, 403)
      }

      if (!inviteRoles.has(invite.target_role)) {
        return safeJson({ ok: false, reason: 'invite_role_forbidden' }, 403)
      }

      orgId = invite.organization_id
      finalRole = invite.target_role
      onboardingStatus = autoApprove ? 'active' : 'pending_activation'

      await admin
        .from('organization_invites')
        .update({ status: 'accepted', accepted_at: now, accepted_by: user.id })
        .eq('id', invite.id)
        .eq('status', 'pending')
    } else if (openSignupRoles.has(requestedRole)) {
      const workspaceType = requestedRole === 'sourcing_manager'
        ? 'sourcing_manager_workspace'
        : 'broker_workspace'
      const { data: org, error: orgError } = await admin
        .from('organizations')
        .insert({
          name: company || `${fullName} Workspace`,
          status: 'active',
          metadata: {
            area,
            city,
            workspace_type: workspaceType,
            signup_source: 'self_signup',
          },
        })
        .select('id')
        .single()

      if (orgError || !org) return safeJson({ ok: false, reason: 'organization_failed' }, 500)
      orgId = org.id
    }

    await admin.from('user_profiles').upsert({
      user_id: user.id,
      full_name: fullName,
      display_alias: displayAlias(user.id),
      profile_completed: orgId !== null,
      onboarding_completed_at: orgId ? now : null,
      updated_at: now,
    }, { onConflict: 'user_id' })

    if (!orgId) {
      await admin.from('onboarding_requests').insert({
        requested_for_user_id: user.id,
        requested_by: user.id,
        request_type: 'organization_onboarding',
        status: 'open',
        reason_code: requestedRole,
      })

      await recordAudit(admin, user.id, null, user.id, 'user_onboarded', {
        role_id: requestedRole,
        status: 'pending_access',
      })

      return safeJson({ ok: true, status: 'pending_access' })
    }

    await admin.from('pilot_users').upsert({
      user_id: user.id,
      org_id: orgId,
      role: legacyRole(finalRole),
      status: autoApprove ? 'active' : 'disabled',
      metadata: {
        company,
        area,
        city,
        project_interest: projectInterest,
        onboarding_status: onboardingStatus,
      },
    }, { onConflict: 'user_id, org_id' })

    if (finalRole === 'broker_owner' || finalRole === 'broker_agent') {
      const brokerProfile = {
        linked_user_id: user.id,
        assigned_sourcing_manager_id: user.id,
        broker_code: brokerCode(company, user.id),
        broker_alias: displayAlias(user.id),
        broker_name: fullName,
        company_name: company || `${fullName} Business`,
        area,
        city,
        speciality: projectInterest || 'Local buyer network',
        verified_status: autoApprove ? 'verified_active' : 'pending_verification',
        verified_performance_rank: 'Silver',
        category: 'active',
        status: autoApprove ? 'active' : 'inactive',
        organization_id: orgId,
        created_by: user.id,
        notes_safe: 'Self signup broker workspace created.',
      }

      const { data: existingBroker } = await admin
        .from('brokers_public')
        .select('id')
        .eq('linked_user_id', user.id)
        .maybeSingle()

      if (existingBroker?.id) {
        await admin
          .from('brokers_public')
          .update(brokerProfile)
          .eq('id', existingBroker.id)
      } else {
        await admin.from('brokers_public').insert(brokerProfile)
      }
    }

    const templateId = await defaultTemplateForRole(admin, orgId, finalRole, user.id)
    if (!templateId) return safeJson({ ok: false, reason: 'template_failed' }, 500)

    await admin
      .from('role_assignments')
      .update({ status: 'inactive', revoked_at: now, revoked_by: user.id })
      .eq('organization_id', orgId)
      .eq('user_id', user.id)
      .eq('status', 'active')

    const { error: roleError } = await admin.from('role_assignments').insert({
      organization_id: orgId,
      user_id: user.id,
      role_id: finalRole,
      permission_template_id: templateId,
      assigned_by: user.id,
      status: autoApprove ? 'active' : 'inactive',
    })

    if (roleError) return safeJson({ ok: false, reason: 'role_assignment_failed' }, 500)

    await recordAudit(admin, user.id, orgId, user.id, 'user_onboarded', {
      organization_id: orgId,
      role_id: finalRole,
      status: onboardingStatus,
    })

    return safeJson({ ok: true, status: onboardingStatus })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
