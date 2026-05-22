// Practical MVP v0.1: lead-from-broker
// Secure intake of customer leads received from external brokers.

// @ts-ignore: Deno module
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { adminClient, currentUser, requirePermission, safeJson, validUuid, cleanText, recordAudit } from "../_shared/sprint7.ts"

const ALLOWED_ACTIONS = new Set([
  'create_lead_from_broker',
  'update_lead_status',
  'schedule_visit_from_lead'
])

const LEAD_STATUSES = new Set([
  'new',
  'loan_active',
  'call_queued',
  'call_blocked',
  'interested',
  'call_later',
  'not_reachable',
  'wrong_lead',
  'budget_mismatch',
  'location_mismatch',
  'visit_scheduled',
  'visit_verified',
  'locked',
  'revoked',
])

const PHONE_REGEX = /(\+?\d{1,4}[\s-]?)?\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{4}/

function sanitizeNotes(text: string): string {
  if (!text) return ''
  let cleaned = cleanText(text, 500)
  if (PHONE_REGEX.test(cleaned)) {
    return "[CLEANED: Contact info removed to comply with Dataless Constitution]"
  }
  return cleaned
}

function safeLeadStatus(value: unknown): string {
  if (typeof value !== 'string') return 'new'
  const cleaned = cleanText(value, 40)
  return LEAD_STATUSES.has(cleaned) ? cleaned : 'new'
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: "unauthorized" }, 401)

    const admin = adminClient()
    const body = await req.json()
    const { action, organization_id } = body

    if (!action || !ALLOWED_ACTIONS.has(action)) {
      return safeJson({ ok: false, reason: "invalid_action" }, 400)
    }

    const orgId = validUuid(organization_id)
    if (!orgId) return safeJson({ ok: false, reason: "invalid_organization" }, 400)

    // Check Pilot/Org Status
    const { data: pilot } = await admin
      .from('pilot_users')
      .select('status, organizations(status)')
      .eq('user_id', user.id)
      .eq('org_id', orgId)
      .maybeSingle()

    if (!pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    // Permission Check
    const canManage = await requirePermission(admin, user.id, 'can_manage_broker_crm', orgId)
    const canUpload = await requirePermission(admin, user.id, 'can_upload_leads', orgId)
    const canCreateSiteVisits = await requirePermission(admin, user.id, 'can_create_site_visits', orgId)

    if ((action === 'create_lead_from_broker' || action === 'update_lead_status') && !canManage && !canUpload) {
      return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)
    }

    if (action === 'schedule_visit_from_lead' && !canManage && !canCreateSiteVisits) {
      return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)
    }

    // -------------------------------------------------------------------------
    // ACTION: create_lead_from_broker
    // -------------------------------------------------------------------------
    if (action === 'create_lead_from_broker') {
      const {
        source_broker_id,
        project_id,
        lead_alias,
        area,
        city,
        budget_min,
        budget_max,
        expected_visit_date,
        lead_status,
        phone,
        notes_safe
      } = body

      const bId = validUuid(source_broker_id)
      const pId = validUuid(project_id)
      if (!bId || !lead_alias) return safeJson({ ok: false, reason: "missing_required_fields" }, 400)

      // 1. Verify Broker belongs to Org
      const { data: brokerCheck } = await admin
        .from('brokers_public')
        .select('id, assigned_sourcing_manager_id')
        .eq('id', bId)
        .eq('organization_id', orgId)
        .single()
      
      if (!brokerCheck) return safeJson({ ok: false, reason: "broker_not_found_in_org" }, 404)
      const assignedManagerId = validUuid(brokerCheck.assigned_sourcing_manager_id)
      if (!assignedManagerId) return safeJson({ ok: false, reason: "broker_manager_not_ready" }, 409)

      let ciphertext: string | null = null
      let phoneHash: string | null = null

      // 1. Prepare PII & Check Duplicates if phone provided
      if (phone) {
        const encryptionKey = Deno.env.get("PHONE_ENCRYPTION_KEY") || ""
        const hashSalt = Deno.env.get("PHONE_HASH_SALT") || "default_broker_salt_2026"

        const { data: ingestion, error: ingestError } = await admin.rpc('ingest_lead_contact_secure', {
          p_contact: phone,
          p_enc_key: encryptionKey,
          p_hash_salt: hashSalt
        })

        if (ingestError || !ingestion || ingestion.length === 0) {
          throw new Error('encryption_failed')
        }

        ciphertext = ingestion[0].ciphertext
        phoneHash = ingestion[0].phone_hash

        // Check for duplicates in this Org
        const { data: duplicateCheck } = await admin.rpc('check_duplicate_lead', {
          p_phone_hash: phoneHash,
          p_org_id: orgId
        })

        if (duplicateCheck && duplicateCheck.length > 0 && duplicateCheck[0].is_duplicate) {
          const dup = duplicateCheck[0]
          // Record Attempted Duplicate Abuse Event
          await admin.from('abuse_events').insert({
            organization_id: orgId,
            actor_id: user.id,
            lead_id: dup.existing_lead_id,
            event_type: 'duplicate_lock_attempt',
            severity: 'medium',
            evidence_ref: {
              attempted_alias: lead_alias,
              existing_alias: dup.existing_lead_alias,
              lock_status: dup.lock_status
            }
          })

          return safeJson({
            ok: false,
            reason: "duplicate_lead_detected",
            alias: dup.existing_lead_alias,
            is_locked: dup.lock_status === 'active'
          }, 409)
        }
      }

      // 2. Create Public Lead
      const { data: lead, error: leadError } = await admin
        .from('leads_public')
        .insert({
          organization_id: orgId,
          source_broker_id: bId,
          broker_id: user.id,
          assigned_manager_id: assignedManagerId,
          assigned_sourcing_manager_id: assignedManagerId,
          alias: cleanText(lead_alias),
          area: cleanText(area),
          city: cleanText(city),
          project_id: pId,
          budget_min: budget_min || 0,
          budget_max: budget_max || 0,
          lead_status: safeLeadStatus(lead_status)
        })
        .select('id')
        .single()

      if (leadError || !lead) throw leadError

      // 3. Store Sensitive Data if prepared
      if (ciphertext && phoneHash) {
        await admin.from('leads_sensitive').insert({
          lead_id: lead.id,
          phone_ciphertext: ciphertext,
          phone_hash: phoneHash,
          encryption_version: 1
        })
      }

      // 4. Log Broker Activity
      await admin.from('broker_activity_logs').insert({
        organization_id: orgId,
        broker_id: bId,
        project_id: pId,
        actor_id: user.id,
        activity_type: 'lead_received',
        notes_safe: sanitizeNotes(notes_safe || 'Broker-sourced lead received.')
      })

      // 5. Create Audit Event
      await recordAudit(admin, user.id, orgId, lead.id, 'lead_received_from_broker', {
        broker_id: bId,
        source: 'external_broker'
      })

      return safeJson({ ok: true, lead_id: lead.id, lead_alias: lead_alias, status: 'lead_received' })
    }

    // -------------------------------------------------------------------------
    // ACTION: update_lead_status
    // -------------------------------------------------------------------------
    if (action === 'update_lead_status') {
      const { lead_id, status } = body
      const lId = validUuid(lead_id)
      if (!lId || !status) return safeJson({ ok: false, reason: "invalid_input" }, 400)

      const nextStatus = safeLeadStatus(status)
      const { error: updateError } = await admin
        .from('leads_public')
        .update({ lead_status: nextStatus, updated_at: new Date().toISOString() })
        .eq('id', lId)
        .eq('organization_id', orgId)

      if (updateError) throw updateError

      return safeJson({ ok: true, status: nextStatus })
    }

    // -------------------------------------------------------------------------
    // ACTION: schedule_visit_from_lead
    // -------------------------------------------------------------------------
    if (action === 'schedule_visit_from_lead') {
      const { lead_id, source_broker_id, project_id, scheduled_at } = body
      const lId = validUuid(lead_id)
      const bId = validUuid(source_broker_id)
      const pId = validUuid(project_id)
      
      if (!lId || !scheduled_at) {
        return safeJson({ ok: false, reason: "missing_required_fields" }, 400)
      }

      // 1. Verify access to lead and broker
      const { data: lead } = await admin
        .from('leads_public')
        .select('id, alias, project_id, source_broker_id')
        .eq('id', lId)
        .eq('organization_id', orgId)
        .single()
      
      if (!lead) return safeJson({ ok: false, reason: "lead_not_found" }, 404)

      const resolvedBrokerId = bId ?? validUuid(lead.source_broker_id)
      if (!resolvedBrokerId) {
        return safeJson({ ok: false, reason: "broker_not_found_in_org" }, 404)
      }

      const { data: brokerCheck } = await admin
        .from('brokers_public')
        .select('id')
        .eq('id', resolvedBrokerId)
        .eq('organization_id', orgId)
        .single()

      if (!brokerCheck) return safeJson({ ok: false, reason: "broker_not_found_in_org" }, 404)

      let resolvedProjectId = pId ?? validUuid(lead.project_id)
      if (!resolvedProjectId) {
        const { data: activation } = await admin
          .from('broker_activations')
          .select('project_id')
          .eq('organization_id', orgId)
          .eq('broker_id', resolvedBrokerId)
          .order('updated_at', { ascending: false })
          .limit(1)
          .maybeSingle()

        resolvedProjectId = validUuid(activation?.project_id)
      }

      if (!resolvedProjectId) {
        return safeJson({ ok: false, reason: "project_not_found_in_org" }, 404)
      }

      const { data: projectCheck } = await admin
        .from('projects')
        .select('id')
        .eq('id', resolvedProjectId)
        .eq('organization_id', orgId)
        .single()

      if (!projectCheck) return safeJson({ ok: false, reason: "project_not_found_in_org" }, 404)

      // 2. Create Site Visit
      const { data: visit, error: visitError } = await admin
        .from('site_visits')
        .insert({
          organization_id: orgId,
          lead_id: lId,
          source_lead_id: lId,
          broker_id: user.id, // Internal broker link (required field from Sprint 1)
          source_broker_id: resolvedBrokerId, // External broker link (Practical MVP)
          sourcing_manager_id: user.id,
          project_id: resolvedProjectId,
          status: 'scheduled',
          scheduled_at: scheduled_at
        })
        .select('id')
        .single()

      if (visitError) throw visitError

      // 3. Update Lead Status
      await admin
        .from('leads_public')
        .update({ lead_status: 'visit_scheduled' })
        .eq('id', lId)
        .eq('organization_id', orgId)

      // 4. Log Broker Activity
      await admin.from('broker_activity_logs').insert({
        organization_id: orgId,
        broker_id: resolvedBrokerId,
        project_id: resolvedProjectId,
        actor_id: user.id,
        activity_type: 'meeting_scheduled',
        notes_safe: 'Site visit scheduled for broker-sourced lead.'
      })

      // 5. Audit Event
      await recordAudit(admin, user.id, orgId, lId, 'site_visit_scheduled_from_broker_lead', {
        broker_id: resolvedBrokerId,
        visit_id: visit.id
      })

      return safeJson({ ok: true, site_visit_id: visit.id, status: 'scheduled' })
    }

    return safeJson({ ok: false, reason: "unimplemented_action" }, 501)

  } catch (err) {
    return safeJson({ ok: false, reason: "internal_error" }, 500)
  }
})
