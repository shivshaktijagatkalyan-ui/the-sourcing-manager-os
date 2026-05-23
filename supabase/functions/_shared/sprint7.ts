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

export function sanitizeHtml(value: unknown): string {
  if (typeof value !== 'string') return ''
  let sanitized = value.replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
  sanitized = sanitized.replace(/<[^>]*>/g, '')
  return sanitized.trim()
}

export function validateEmail(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
  return emailRegex.test(value) ? value.trim().toLowerCase() : null
}

export function validatePhone(value: unknown): string | null {
  if (typeof value !== 'string') return null
  const cleaned = value.replace(/[\s-]/g, '')
  const phoneRegex = /^(?:\+91|0)?[6-9]\d{9}$/
  return phoneRegex.test(cleaned) ? cleaned : null
}

export function validateAlphanumeric(value: unknown, maxLen = 120): string | null {
  if (typeof value !== 'string') return null
  const cleaned = value.replace(/[^a-zA-Z0-9\s-_]/g, '').trim()
  return cleaned.length > 0 ? cleaned.slice(0, maxLen) : null
}

export async function checkRateLimit(
  userId: string,
  action: string,
  organizationId?: string,
  customLimitPerMin?: number
): Promise<{ ok: boolean; reason?: string }> {
  const admin = adminClient()

  const ACTION_LIMITS: Record<string, number> = {
    'initiate_call': 5,
    'broker_upload_lead': 20,
    'create_site_visit': 10,
    'verify_site_gps': 30,
    'incident_action': 3,
    'upload_site_photo': 10,
  }

  const limit = customLimitPerMin ?? ACTION_LIMITS[action] ?? 50
  const oneMinuteAgo = new Date(Date.now() - 60 * 1000).toISOString()

  const { count, error: countError } = await admin
    .from('rate_limit_events')
    .select('id', { count: 'exact', head: true })
    .eq('actor_id', userId)
    .eq('action', action)
    .gte('blocked_at', oneMinuteAgo)

  if (countError) {
    throw new Error('rate_limit_check_failed')
  }

  if (count !== null && count >= limit) {
    await admin.from('audit_events').insert({
      actor_id: userId,
      event_type: 'rate_limit_blocked',
      event_context: {
        action,
        count,
        limit,
        organization_id: organizationId ?? null,
      },
    })
    return { ok: false, reason: 'rate_limit_exceeded' }
  }

  const { error: insertError } = await admin.from('rate_limit_events').insert({
    actor_id: userId,
    organization_id: organizationId ?? null,
    action,
    limit_key: `${userId}:${action}`,
  })

  if (insertError) {
    throw new Error('rate_limit_record_failed')
  }

  return { ok: true }
}

export function verifyApiVersion(req: Request, minSupportedVersion = 1): { ok: boolean; version?: number } {
  const versionHeader = req.headers.get('X-API-Version')
  let version: number | null = null

  if (versionHeader) {
    const parsed = parseInt(versionHeader, 10)
    if (!isNaN(parsed)) version = parsed
  } else {
    const acceptHeader = req.headers.get('Accept')
    if (acceptHeader) {
      const match = acceptHeader.match(/application\/vnd\.sourcing-manager\.v(\d+)\+json/)
      if (match) {
        version = parseInt(match[1], 10)
      }
    }
  }

  if (version === null) {
    version = 1
  }

  if (version < minSupportedVersion) {
    return { ok: false, version }
  }

  return { ok: true, version }
}

export async function sha256(value: string) {
  const data = new TextEncoder().encode(value)
  const hash = await crypto.subtle.digest('SHA-256', data)
  return Array.from(new Uint8Array(hash)).map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

export async function hmacSha256(value: string, secret: string) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(value))
  return Array.from(new Uint8Array(signature)).map((byte) => byte.toString(16).padStart(2, '0')).join('')
}

export function timingSafeEqualHex(left: string, right: string) {
  if (!/^[0-9a-f]+$/i.test(left) || !/^[0-9a-f]+$/i.test(right)) return false
  if (left.length !== right.length) return false

  let diff = 0
  for (let i = 0; i < left.length; i++) {
    diff |= left.charCodeAt(i) ^ right.charCodeAt(i)
  }
  return diff === 0
}

export async function verifyWebhookSignature(payload: string, signature: string, secret: string) {
  if (!signature || !secret) return false
  const expected = await hmacSha256(payload, secret)
  return timingSafeEqualHex(expected, signature)
}

export function validateImageFileSignature(bytes: Uint8Array): 'image/jpeg' | 'image/png' | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'image/jpeg'
  }
  if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a) {
    return 'image/png'
  }
  return null
}

export function isAllowedUploadSize(size: number, maxSize = 5 * 1024 * 1024) {
  return Number.isFinite(size) && size > 0 && size <= maxSize
}

export const sensitiveEnvNames = new Set([
  'EXOTEL_SECRET',
  'EXOTEL_TOKEN',
  'VOICE_AI_API_KEY',
  'VOICE_AI_SECRET',
  'GOOGLE_OAUTH_CLIENT_SECRET',
  'SUPABASE_SERVICE_ROLE_KEY',
  'SUPABASE_ANON_KEY',
  'SUPABASE_URL',
])

export function isSensitiveEnvName(name: string) {
  return sensitiveEnvNames.has(name)
}

export function validateEnvKeyName(name: string) {
  return typeof name === 'string' && /^[A-Z0-9_]+$/.test(name)
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

  const leadScopedEvents = new Set([
    'abuse_event_flagged',
    'abuse_event_resolved',
    'ai_call_failed',
    'ai_call_initiated',
    'broker_followup_set',
    'broker_issue_raised',
    'broker_self_call_blocked',
    'broker_self_call_provider_config_missing',
    'broker_self_call_provider_failed',
    'broker_self_call_queued',
    'broker_vault_lead_submitted',
    'brokerage_status_updated',
    'booking_stage_updated',
    'call_blocked',
    'call_callback_received',
    'call_callback_rejected',
    'call_provider_config_missing',
    'call_provider_failed',
    'call_queued',
    'data_loan_extended',
    'data_loan_granted',
    'data_loan_revoked',
    'lead_assigned_to_caller',
    'lead_assigned_to_sm',
    'lead_quality_updated',
    'lead_received_from_broker',
    'lead_uploaded',
    'site_visit_scheduled_from_broker_lead',
    'user_freeze_recommended',
  ])

  const contextLeadId = validUuid(context.lead_id)
  const leadId = contextLeadId ?? (leadScopedEvents.has(eventType) ? validUuid(targetUserId) : null)

  await admin.from('audit_events').insert({
    actor_id: actorId,
    lead_id: leadId,
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
