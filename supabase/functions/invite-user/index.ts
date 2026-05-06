import { serve } from 'std/http/server.ts'
import { adminClient, cleanText, corsHeaders, currentUser, privateHash, recordAudit, requirePermission, roles, safeJson, validUuid } from '../_shared/sprint7.ts'

declare const Deno: any;

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'access_denied' }, 401)

    const body = await req.json().catch(() => ({}))
    const orgId = validUuid(body.organization_id)
    const role = cleanText(body.role_id ?? body.role, 60)
    const inviteRef = cleanText(body.invite_ref ?? body.email, 220).toLowerCase()
    if (!orgId || !roles.has(role) || inviteRef.length < 3) return safeJson({ ok: false, reason: 'invalid_input' }, 400)

    const admin = adminClient()
    const allowed = await requirePermission(admin, user.id, 'can_manage_org_users', orgId)
    if (!allowed) return safeJson({ ok: false, reason: 'access_denied' }, 403)

    const inviteCode = crypto.randomUUID().replaceAll('-', '') + crypto.randomUUID().replaceAll('-', '')
    const inviteeHash = await privateHash(inviteRef)
    const inviteTokenHash = await privateHash(inviteCode)

    const { data: invite, error } = await admin
      .from('organization_invites')
      .insert({
        organization_id: orgId,
        invited_email: 'redacted',
        invitee_hash: inviteeHash,
        invite_token_hash: inviteTokenHash,
        target_role: role,
        inviter_user_id: user.id,
        expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
      })
      .select('id')
      .single()

    if (error || !invite) return safeJson({ ok: false, reason: 'invite_failed' }, 500)

    await admin.from('onboarding_requests').insert({
      organization_id: orgId,
      requested_by: user.id,
      request_type: 'user_invite',
      status: 'open',
      reason_code: role,
    })

    await recordAudit(admin, user.id, orgId, null, 'invite_created', {
      organization_id: orgId,
      invite_id: invite.id,
      role_id: role,
    })

    return safeJson({ ok: true, invite_id: invite.id, invite_code: inviteCode })
  } catch {
    return safeJson({ ok: false, reason: 'internal_error' }, 500)
  }
})
