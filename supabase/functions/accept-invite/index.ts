import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, corsHeaders, cleanText, privateHash, legacyRole } from '../_shared/sprint7.ts'



serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'access_denied' }, 401)

    const body = await req.json().catch(() => ({}))
    const inviteCode = cleanText(body.invite_code, 160)
    if (inviteCode.length < 16) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const admin = adminClient()
    const inviteTokenHash = await privateHash(inviteCode)
    const { data: invite, error: readError } = await admin
      .from('organization_invites')
      .select('id, organization_id, target_role, status, expires_at')
      .eq('invite_token_hash', inviteTokenHash)
      .eq('status', 'pending')
      .maybeSingle()

    if (readError || !invite || new Date(invite.expires_at).getTime() <= Date.now()) {
      return safeJson({ ok: false, reason: 'invite_invalid' }, 403)
    }

    const { error: updateError } = await admin
      .from('organization_invites')
      .update({ status: 'accepted', accepted_at: new Date().toISOString(), accepted_by: user.id })
      .eq('id', invite.id)
      .eq('status', 'pending')

    if (updateError) return safeJson({ ok: false, reason: 'accept_failed' }, 409)

    await admin.from('pilot_users').upsert({
      user_id: user.id,
      org_id: invite.organization_id,
      role: legacyRole(invite.target_role),
      status: 'disabled',
    }, { onConflict: 'user_id, org_id' })

    await admin.from('user_profiles').upsert({
      user_id: user.id,
      display_alias: `user-${user.id.slice(0, 8)}`,
      profile_completed: false,
    }, { onConflict: 'user_id' })

    await admin.from('role_assignments').insert({
      organization_id: invite.organization_id,
      user_id: user.id,
      role_id: invite.target_role,
      status: 'active',
    })

    await recordAudit(admin, user.id, invite.organization_id, user.id, 'invite_accepted', {
      organization_id: invite.organization_id,
      invite_id: invite.id,
      role_id: invite.target_role,
      status: 'accepted_pending_activation',
    })

    return safeJson({ ok: true, status: 'pending_activation' })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
