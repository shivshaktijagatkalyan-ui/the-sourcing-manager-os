// @ts-ignore: Deno import
import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, validUuid, corsHeaders } from '../_shared/sprint7.ts'



const eventTypes = new Set([
  'gps_outside_geofence_repeated',
  'gps_accuracy_failure_repeated',
  'photo_overwrite_attempt',
  'call_after_loan_expiry',
  'revoked_loan_access_attempt',
  'duplicate_lock_attempt',
  'broker_rejection_spike',
  'dispute_frequency_spike',
  'inactive_enabled_user',
  'unusual_activity_window',
  'disabled_user_access_attempt',
  'paused_org_access_attempt',
])

const severities = new Set(['low', 'medium', 'high', 'critical'])

function safeSeverity(eventType: string, requested: unknown) {
  if (typeof requested === 'string' && severities.has(requested)) return requested
  if (eventType === 'disabled_user_access_attempt' || eventType === 'paused_org_access_attempt') return 'critical'
  if (eventType === 'duplicate_lock_attempt' || eventType === 'gps_outside_geofence_repeated') return 'high'
  return 'medium'
}

function sanitizeEvidence(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {}
  const blocked = ['phone', 'mobile', 'whatsapp', 'tel', 'contact', 'email', 'name']
  const out: Record<string, unknown> = {}
  for (const [key, raw] of Object.entries(value as Record<string, unknown>)) {
    const lowered = key.toLowerCase()
    if (blocked.some((token) => lowered.includes(token))) continue

    if (typeof raw === 'string' || typeof raw === 'number' || typeof raw === 'boolean' || raw === null) out[key] = raw
  }
  return out
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()

    // 1. Fetch Pilot Context
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status, organizations(status)')
      .eq('user_id', user.id)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    // 2. Strict Permission Check
    const allowed = await requirePermission(admin, user.id, 'can_flag_abuse', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const body = await req.json()
    const eventType = typeof body.event_type === 'string' ? body.event_type : ''
    if (!eventTypes.has(eventType)) return safeJson({ ok: false, reason: 'invalid_event_type' }, 400)

    const severity = safeSeverity(eventType, body.severity)
    const actorId = validUuid(body.actor_id)
    const leadId = validUuid(body.lead_id)
    const siteVisitId = validUuid(body.site_visit_id)
    
    // 3. Verify Actor Scope
    if (actorId) {
      const { data: actorInOrg } = await admin
        .from('pilot_users')
        .select('user_id')
        .eq('user_id', actorId)
        .eq('org_id', pilot.org_id)
        .maybeSingle()
      if (!actorInOrg) return safeJson({ ok: false, reason: 'invalid_actor_scope' }, 403)
    }

    const riskDelta = typeof body.risk_score_delta === 'number' && Number.isFinite(body.risk_score_delta)
      ? Math.max(-5, Math.min(5, body.risk_score_delta))
      : severity === 'critical' ? -1 : severity === 'high' ? -0.5 : -0.1

    // 4. Record Abuse Event
    const { data: event, error } = await admin
      .from('abuse_events')
      .insert({
        actor_id: actorId,
        organization_id: pilot.org_id,
        lead_id: leadId,
        site_visit_id: siteVisitId,
        event_type: eventType,
        severity,
        risk_score_delta: riskDelta,
        evidence_ref: sanitizeEvidence(body.evidence_ref),
      })
      .select('id')
      .single()

    if (error || !event) throw new Error('flag_failed')

    await recordAudit(admin, user.id, pilot.org_id, leadId, 'abuse_event_flagged', { 
        abuse_event_id: event.id, 
        event_type: eventType, 
        severity 
    })

    if (severity === 'critical') {
      await recordAudit(admin, user.id, pilot.org_id, leadId, actorId ? 'user_freeze_recommended' : 'org_freeze_recommended', { 
          abuse_event_id: event.id 
      })
    }

    return safeJson({ ok: true, abuse_event_id: event.id, severity })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})

