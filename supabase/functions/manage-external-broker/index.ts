// Practical MVP v0.1: manage-external-broker
// Secure management of external broker metadata and activation status.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { adminClient, currentUser, requirePermission, safeJson, validUuid, cleanText } from "../_shared/sprint7.ts"

const ALLOWED_ACTIONS = new Set([
  'create_broker',
  'update_broker_metadata',
  'update_activation_stage',
  'create_followup',
  'complete_followup',
  'log_activity'
])

const PHONE_REGEX = /(\+?\d{1,4}[\s-]?)?\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{4}/

function sanitizeNotes(text: string): string {
  if (!text) return ''
  // 1. Basic cleaning
  let cleaned = cleanText(text, 500)
  // 2. Constitution Enforcement: Reject obvious phone numbers/contact info
  if (PHONE_REGEX.test(cleaned)) {
    return "[CLEANED: Contact info removed to comply with Dataless Constitution]"
  }
  return cleaned
}

async function brokerAccess(admin: ReturnType<typeof adminClient>, brokerId: string, orgId: string) {
  const { data } = await admin
    .from('brokers_public')
    .select('id, assigned_sourcing_manager_id')
    .eq('id', brokerId)
    .eq('organization_id', orgId)
    .maybeSingle()

  return data
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
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('status, organizations(status)')
      .eq('user_id', user.id)
      .eq('org_id', orgId)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    // Permission Check
    const isManager = await requirePermission(admin, user.id, 'can_view_assigned_broker', orgId)
    const isAdmin = await requirePermission(admin, user.id, 'can_manage_broker_crm', orgId)

    if (!isManager && !isAdmin) {
      return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)
    }

    // -------------------------------------------------------------------------
    // ACTION: create_broker
    // -------------------------------------------------------------------------
    if (action === 'create_broker') {
      const {
        broker_alias,
        broker_name,
        company_name,
        area,
        city,
        speciality,
        category,
        interest_level,
        notes_safe,
        phone,
        email,
        assigned_to // Optional: defaults to self
      } = body

      if (!broker_alias) return safeJson({ ok: false, reason: "missing_alias" }, 400)

      const assignedSourcingManagerId = isAdmin && assigned_to ? assigned_to : user.id

      // 1. Create Public Record
      const { data: broker, error: createError } = await admin
        .from('brokers_public')
        .insert({
          organization_id: orgId,
          assigned_sourcing_manager_id: assignedSourcingManagerId,
          broker_alias: cleanText(broker_alias),
          broker_name: cleanText(broker_name),
          company_name: cleanText(company_name),
          area: cleanText(area),
          city: cleanText(city),
          speciality: cleanText(speciality),
          category: category || 'new',
          interest_level: interest_level || 'unknown',
          notes_safe: sanitizeNotes(notes_safe),
          created_by: user.id
        })
        .select('id')
        .single()

      if (createError || !broker) throw createError

      // 2. Encrypt Sensitive Info if provided
      if (phone || email) {
        let phoneCiphertext = null
        let emailCiphertext = null

        const encryptionKey = Deno.env.get("PHONE_ENCRYPTION_KEY") || ""
        
        if (phone) {
          const { data: cipher } = await admin.rpc('encrypt_lead_contact', {
            p_contact: phone,
            p_key: encryptionKey
          })
          phoneCiphertext = cipher
        }

        if (email) {
          const { data: cipher } = await admin.rpc('encrypt_lead_contact', {
            p_contact: email,
            p_key: encryptionKey
          })
          emailCiphertext = cipher
        }

        await admin.from('brokers_sensitive').insert({
          broker_id: broker.id,
          phone_ciphertext: phoneCiphertext,
          email_ciphertext: emailCiphertext,
          encryption_version: 1
        })
      }

      return safeJson({ ok: true, broker_id: broker.id, status: 'created' })
    }

    // -------------------------------------------------------------------------
    // ACTION: update_activation_stage
    // -------------------------------------------------------------------------
    if (action === 'update_activation_stage') {
      const { broker_id, project_id, stage, notes, potential_score } = body
      const bId = validUuid(broker_id)
      const pId = validUuid(project_id)

      if (!bId || !pId || !stage) return safeJson({ ok: false, reason: "invalid_input" }, 400)

      // Verify assignment/ownership
      const brokerCheck = await brokerAccess(admin, bId, orgId)

      if (!brokerCheck || (brokerCheck.assigned_sourcing_manager_id !== user.id && !isAdmin)) {
        return safeJson({ ok: false, reason: "forbidden_assignment" }, 403)
      }

      const { data: activation, error: upsertError } = await admin
        .from('broker_activations')
        .upsert({
          organization_id: orgId,
          broker_id: bId,
          project_id: pId,
          assigned_sourcing_manager_id: brokerCheck.assigned_sourcing_manager_id,
          activation_stage: stage,
          stage_notes: sanitizeNotes(notes),
          potential_score: potential_score || 0,
          last_contacted_at: new Date().toISOString()
        }, { onConflict: 'organization_id,broker_id,project_id' })
        .select('id')
        .single()

      if (upsertError) throw upsertError

      return safeJson({ ok: true, activation_id: activation.id, status: 'updated' })
    }

    // -------------------------------------------------------------------------
    // ACTION: create_followup
    // -------------------------------------------------------------------------
    if (action === 'create_followup') {
      const { broker_id, project_id, due_at, reason, priority } = body
      const bId = validUuid(broker_id)
      if (!bId || !due_at) return safeJson({ ok: false, reason: "invalid_input" }, 400)

      const brokerCheck = await brokerAccess(admin, bId, orgId)
      if (!brokerCheck || (brokerCheck.assigned_sourcing_manager_id !== user.id && !isAdmin)) {
        return safeJson({ ok: false, reason: "forbidden_assignment" }, 403)
      }

      const { data: followup, error: fError } = await admin
        .from('broker_followups')
        .insert({
          organization_id: orgId,
          broker_id: bId,
          project_id: validUuid(project_id),
          assigned_to: user.id,
          due_at,
          reason: cleanText(reason),
          priority: priority || 'normal'
        })
        .select('id')
        .single()

      if (fError) throw fError

      return safeJson({ ok: true, followup_id: followup.id })
    }

    // -------------------------------------------------------------------------
    // ACTION: log_activity
    // -------------------------------------------------------------------------
    if (action === 'log_activity') {
      const { broker_id, project_id, activity_type, notes, next_followup_at } = body
      const bId = validUuid(broker_id)
      if (!bId || !activity_type) return safeJson({ ok: false, reason: "invalid_input" }, 400)

      const brokerCheck = await brokerAccess(admin, bId, orgId)
      if (!brokerCheck || (brokerCheck.assigned_sourcing_manager_id !== user.id && !isAdmin)) {
        return safeJson({ ok: false, reason: "forbidden_assignment" }, 403)
      }

      const { data: log, error: lError } = await admin
        .from('broker_activity_logs')
        .insert({
          organization_id: orgId,
          broker_id: bId,
          project_id: validUuid(project_id),
          actor_id: user.id,
          activity_type,
          notes_safe: sanitizeNotes(notes),
          next_followup_at
        })
        .select('id')
        .single()

      if (lError) throw lError

      return safeJson({ ok: true, log_id: log.id })
    }

    return safeJson({ ok: false, reason: "unimplemented_action" }, 501)

  } catch (err) {
    return safeJson({ ok: false, reason: "internal_error" }, 500)
  }
})
