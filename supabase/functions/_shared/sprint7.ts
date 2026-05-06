import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

export const roles = new Set([
  'platform_admin',
  'developer_admin',
  'broker_owner',
  'broker_agent',
  'sourcing_manager',
  'caller',
  'compliance_admin',
  'dispute_admin',
  'finance_admin',
  'read_only_auditor',
])

export const permissions = new Set([
  'can_upload_leads',
  'can_grant_data_loans',
  'can_call_leads',
  'can_create_site_visits',
  'can_verify_site_visits',
  'can_review_site_visits',
  'can_view_disputes',
  'can_resolve_disputes',
  'can_view_payouts',
  'can_generate_statements',
  'can_view_compliance_reports',
  'can_manage_org_users',
  'can_pause_org',
  'can_suspend_user',
  'can_view_assigned_broker',
  'can_manage_broker_crm',
  'can_manage_payouts',
  'can_flag_abuse',
  'can_resolve_abuse',
  'can_generate_risk_summaries',
  'can_run_trust_decay',
  'can_view_audit_logs',
])

export function safeJson(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

export function env(name: string) {
  const value = Deno.env.get(name)
  if (!value) throw new Error('server_error')
  return value
}

export function adminClient() {
  return createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'))
}

export function anonClient(req: Request) {
  return createClient(env('SUPABASE_URL'), env('SUPABASE_ANON_KEY'), {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  })
}

export async function currentUser(req: Request) {
  const header = req.headers.get('Authorization')
  if (!header) return null
  const { data, error } = await anonClient(req).auth.getUser()
  if (error || !data.user) return null
  return data.user
}

export function validUuid(value: unknown) {
  if (typeof value !== 'string') return null
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value) ? value : null
}

export function cleanText(value: unknown, max = 120) {
  if (typeof value !== 'string') return ''
  return value.replace(/[\u0000-\u001F\u007F]/g, '').trim().slice(0, max)
}

export async function sha256(value: string) {
  const data = new TextEncoder().encode(value)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(hash)).map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

export async function privateHash(value: string) {
  return sha256(`${value}:${env('SUPABASE_SERVICE_ROLE_KEY')}`)
}

export function legacyRole(role: string) {
  if (['platform_admin', 'developer_admin', 'compliance_admin', 'dispute_admin', 'finance_admin', 'read_only_auditor'].includes(role)) return 'admin'
  if (['broker_owner', 'broker_agent'].includes(role)) return 'broker'
  if (role === 'sourcing_manager') return 'sourcing_manager'
  return 'caller'
}

export async function requirePermission(admin: ReturnType<typeof createClient>, userId: string, permission: string, orgId?: string) {
  const { data, error } = await admin.rpc('has_strict_enterprise_permission', {
    p_user_id: userId,
    p_permission: permission,
    p_org_id: orgId ?? null,
  })
  return !error && data === true
}

export async function recordAudit(
  admin: ReturnType<typeof createClient>,
  actorId: string | null,
  orgId: string | null,
  targetUserId: string | null,
  eventType: string,
  context: Record<string, unknown>,
) {
  const onboardingEvents = new Set([
    'organization_created',
    'invite_created',
    'invite_accepted',
    'role_assigned',
    'permission_template_updated',
    'user_activated',
    'user_deactivated',
    'user_suspended',
    'org_paused',
    'org_resumed',
  ])

  if (onboardingEvents.has(eventType)) {
    await admin.rpc('record_onboarding_audit', {
      p_actor_id: actorId,
      p_organization_id: orgId,
      p_target_user_id: targetUserId,
      p_event_type: eventType,
      p_context: context,
    })
    return
  }

  await admin.from('audit_events').insert({
    actor_id: actorId,
    event_type: eventType,
    event_context: {
      ...context,
      organization_id: orgId,
      target_user_id: targetUserId,
    },
  })
}

export async function defaultTemplateForRole(
  admin: ReturnType<typeof createClient>,
  orgId: string,
  role: string,
  actorId: string,
) {
  const { data: existing } = await admin
    .from('permission_templates')
    .select('id')
    .eq('organization_id', orgId)
    .eq('name', `${role}_default`)
    .eq('status', 'active')
    .maybeSingle()

  if (existing?.id) return existing.id as string

  const { data: template, error: templateError } = await admin
    .from('permission_templates')
    .insert({
      organization_id: orgId,
      name: `${role}_default`,
      created_by: actorId,
      updated_by: actorId,
    })
    .select('id')
    .single()

  if (templateError || !template) return null

  const { data: rolePerms } = await admin
    .from('role_permissions')
    .select('permission_id')
    .eq('role_id', role)

  const rows = (rolePerms ?? []).map((row) => ({ template_id: template.id, permission_id: row.permission_id }))
  if (rows.length > 0) await admin.from('permission_template_permissions').insert(rows)

  return template.id as string
}
