import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  cleanText,
  corsHeaders,
  currentUser,
  requirePermission,
  safeJson,
  validUuid,
  recordAudit,
} from "../_shared/sprint7.ts"

const actions = new Set([
  "submit_lead",
  "assign_to_sm",
  "assign_to_caller",
  "update_lead_quality",
  "set_followup",
  "update_booking_stage",
  "update_brokerage_status",
  "raise_issue",
])

const leadQualities = new Set([
  "hot",
  "warm",
  "cold",
  "investor",
  "end_user",
  "budget_matched",
  "location_matched",
  "project_matched",
  "duplicate_risk",
  "low_quality",
  "loan_required",
  "family_decision_pending",
  "site_visit_ready",
])

const bookingStages = new Set([
  "not_started",
  "booking_discussion",
  "token_discussion",
  "token_paid",
  "booking_confirmed",
  "loan_legal_started",
  "agreement_pending",
  "payment_pending",
  "closed",
  "lost",
])

const brokerageStatuses = new Set([
  "tracking",
  "pending_visit",
  "locked",
  "eligible",
  "paid",
  "disputed",
  "blocked",
])

const issueTypes = new Set([
  "brokerage_credit",
  "site_visit_proof",
  "caller_support",
  "data_access",
  "other",
])

const digits = /(\+?\d{1,4}[\s-]?)?\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{4}/g

function safeNotes(value: unknown) {
  const cleaned = cleanText(value, 500)
  if (!cleaned) return ""
  return digits.test(cleaned) ? "[CLEANED: Contact info removed]" : cleaned
}

function safeQuality(value: unknown) {
  const cleaned = cleanText(value, 40).toLowerCase()
  return leadQualities.has(cleaned) ? cleaned : "warm"
}

function safeBookingStage(value: unknown) {
  const cleaned = cleanText(value, 40).toLowerCase()
  return bookingStages.has(cleaned) ? cleaned : "not_started"
}

function safeBrokerageStatus(value: unknown) {
  const cleaned = cleanText(value, 40).toLowerCase()
  return brokerageStatuses.has(cleaned) ? cleaned : "tracking"
}

function scoreData(body: Record<string, unknown>) {
  let score = 0
  if (Number(body.budget_min ?? 0) > 0 || Number(body.budget_max ?? 0) > 0) score += 15
  if (cleanText(body.area, 80)) score += 15
  if (validUuid(body.project_id)) score += 15
  if (cleanText(body.buyer_type, 40)) score += 10
  if (body.next_followup_at) score += 15
  if (body.duplicate_risk !== true) score += 10
  if (cleanText(body.lead_quality, 40) === "hot") score += 10
  if (body.visit_scheduled === true) score += 10
  return Math.max(0, Math.min(100, score))
}

async function actorContext(admin: ReturnType<typeof adminClient>, userId: string) {
  const { data } = await admin
    .from("pilot_users")
    .select("org_id, status, organizations(status)")
    .eq("user_id", userId)
    .maybeSingle()

  if (!data || data.status !== "active" || data.organizations?.status !== "active") return null
  return { orgId: data.org_id as string }
}

async function linkedBrokerId(admin: ReturnType<typeof adminClient>, userId: string, orgId: string) {
  const { data } = await admin
    .from("brokers_public")
    .select("id")
    .eq("linked_user_id", userId)
    .eq("organization_id", orgId)
    .eq("status", "active")
    .maybeSingle()

  return validUuid(data?.id)
}

async function canUseLead(admin: ReturnType<typeof adminClient>, userId: string, orgId: string, leadId: string) {
  const { data: lead } = await admin
    .from("leads_public")
    .select("id, organization_id, source_broker_id, broker_id, project_id")
    .eq("id", leadId)
    .eq("organization_id", orgId)
    .maybeSingle()

  if (!lead) return null

  const canManage = await requirePermission(admin, userId, "can_manage_broker_crm", orgId)
  const canGrant = await requirePermission(admin, userId, "can_grant_data_loans", orgId)
  if (canManage || canGrant || lead.broker_id === userId) return lead

  const sourceBrokerId = validUuid(lead.source_broker_id)
  if (!sourceBrokerId) return null

  const { data: linked } = await admin.rpc("is_linked_broker_user", {
    p_broker_id: sourceBrokerId,
    p_user_id: userId,
  })

  return linked === true ? lead : null
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: "unauthorized" }, 401)

    const admin = adminClient()
    const context = await actorContext(admin, user.id)
    if (!context) return safeJson({ ok: false, reason: "access_blocked_operational" }, 403)

    const body = await req.json().catch(() => ({}))
    const action = typeof body.action === "string" ? body.action : ""
    if (!actions.has(action)) return safeJson({ ok: false, reason: "invalid_action" }, 400)

    if (action === "submit_lead") {
      const brokerId = validUuid(body.source_broker_id) ?? (await linkedBrokerId(admin, user.id, context.orgId))
      if (!brokerId) return safeJson({ ok: false, reason: "broker_not_found" }, 404)

      const { data: broker } = await admin
        .from("brokers_public")
        .select("id, organization_id, assigned_sourcing_manager_id")
        .eq("id", brokerId)
        .eq("organization_id", context.orgId)
        .eq("status", "active")
        .maybeSingle()

      if (!broker) return safeJson({ ok: false, reason: "broker_not_found" }, 404)

      const alias = cleanText(body.lead_alias ?? body.alias, 80)
      if (!alias) return safeJson({ ok: false, reason: "missing_alias" }, 400)

      const projectId = validUuid(body.project_id)
      const nextFollowup = body.next_followup_at ? new Date(body.next_followup_at).toISOString() : null
      const { data: lead, error } = await admin
        .from("leads_public")
        .insert({
          organization_id: context.orgId,
          broker_id: user.id,
          source_broker_id: brokerId,
          assigned_manager_id: broker.assigned_sourcing_manager_id,
          assigned_sourcing_manager_id: broker.assigned_sourcing_manager_id,
          project_id: projectId,
          alias,
          area: cleanText(body.area, 100),
          city: cleanText(body.city, 100),
          property_name: cleanText(body.property_name, 120),
          budget_min: Number(body.budget_min ?? 0),
          budget_max: Number(body.budget_max ?? 0),
          lead_status: "new",
          lead_quality: safeQuality(body.lead_quality),
          lead_temperature: safeQuality(body.lead_temperature),
          buyer_type: cleanText(body.buyer_type, 40) || "end_user",
          project_match_status: cleanText(body.project_match_status, 40) || "project_matched",
          next_followup_at: nextFollowup,
          broker_notes_safe: safeNotes(body.notes_safe),
          conversion_stage: "lead_received",
          booking_stage: "not_started",
          brokerage_status: "tracking",
          data_quality_score: scoreData(body),
        })
        .select("id")
        .single()

      if (error || !lead) return safeJson({ ok: false, reason: "write_failed" }, 409)

      const secretValue = typeof body.secure_value === "string" ? body.secure_value.trim() : ""
      if (secretValue) {
        const { data: cipher } = await admin.rpc("encrypt_lead_contact", {
          p_contact: secretValue,
          p_key: Deno.env.get("PHONE_ENCRYPTION_KEY") ?? "",
        })
        await admin.from("leads_sensitive").insert({
          lead_id: lead.id,
          phone_ciphertext: cipher,
          encryption_version: 1,
        })
      }

      await admin.from("broker_activity_logs").insert({
        organization_id: context.orgId,
        broker_id: brokerId,
        project_id: projectId,
        actor_id: user.id,
        activity_type: "lead_received",
        notes_safe: "Broker lead submitted through vault.",
      })

      await recordAudit(admin, user.id, context.orgId, lead.id, "broker_vault_lead_submitted", {
        broker_id: brokerId,
        project_id: projectId,
      })

      return safeJson({ ok: true, status: "updated" })
    }

    const leadId = validUuid(body.lead_id)
    if (!leadId) return safeJson({ ok: false, reason: "invalid_lead" }, 400)
    const lead = await canUseLead(admin, user.id, context.orgId, leadId)
    if (!lead) return safeJson({ ok: false, reason: "forbidden" }, 403)

    if (action === "assign_to_sm") {
      const requestedManagerId = validUuid(body.sourcing_manager_id)
      let managerId = requestedManagerId

      if (!managerId && validUuid(lead.source_broker_id)) {
        const { data: activation } = await admin
          .from("broker_activations")
          .select("assigned_sourcing_manager_id")
          .eq("organization_id", context.orgId)
          .eq("broker_id", lead.source_broker_id)
          .order("updated_at", { ascending: false })
          .limit(1)
          .maybeSingle()
        managerId = validUuid(activation?.assigned_sourcing_manager_id)
      }

      if (!managerId) return safeJson({ ok: false, reason: "manager_not_found" }, 404)

      const { error } = await admin
        .from("leads_public")
        .update({
          assigned_sourcing_manager_id: managerId,
          assigned_manager_id: managerId,
          conversion_stage: "assigned_to_sm",
          updated_at: new Date().toISOString(),
        })
        .eq("id", leadId)
        .eq("organization_id", context.orgId)

      if (error) return safeJson({ ok: false, reason: "write_failed" }, 409)
      await recordAudit(admin, user.id, context.orgId, leadId, "lead_assigned_to_sm", { manager_id: managerId })
      return safeJson({ ok: true, status: "updated" })
    }

    if (action === "assign_to_caller") {
      const callerId = validUuid(body.caller_id)
      if (!callerId) return safeJson({ ok: false, reason: "caller_required" }, 400)

      const { data: result, error } = await admin.rpc("assign_lead_to_caller_v2", {
        p_lead_id: leadId,
        p_caller_id: callerId,
        p_actor_id: user.id,
        p_org_id: context.orgId,
        p_loan_duration_hours: Number(body.duration_hours ?? 24),
      })

      if (error || result?.ok !== true) return safeJson({ ok: false, reason: "assignment_failed" }, 409)

      await admin
        .from("leads_public")
        .update({ conversion_stage: "assigned_to_caller", updated_at: new Date().toISOString() })
        .eq("id", leadId)
        .eq("organization_id", context.orgId)

      await recordAudit(admin, user.id, context.orgId, leadId, "lead_assigned_to_caller", { caller_id: callerId })
      return safeJson({ ok: true, status: "updated" })
    }

    if (action === "update_lead_quality") {
      const quality = safeQuality(body.lead_quality)
      const { error } = await admin
        .from("leads_public")
        .update({
          lead_quality: quality,
          lead_temperature: ["hot", "warm", "cold"].includes(quality) ? quality : "warm",
          data_quality_score: scoreData({ ...body, lead_quality: quality }),
          updated_at: new Date().toISOString(),
        })
        .eq("id", leadId)
        .eq("organization_id", context.orgId)

      if (error) return safeJson({ ok: false, reason: "write_failed" }, 409)
      await recordAudit(admin, user.id, context.orgId, leadId, "lead_quality_updated", { quality })
      return safeJson({ ok: true, status: "updated" })
    }

    if (action === "set_followup") {
      const nextFollowup = body.next_followup_at ? new Date(body.next_followup_at).toISOString() : null
      if (!nextFollowup) return safeJson({ ok: false, reason: "invalid_followup" }, 400)

      const { error } = await admin
        .from("leads_public")
        .update({
          next_followup_at: nextFollowup,
          conversion_stage: "call_later",
          updated_at: new Date().toISOString(),
        })
        .eq("id", leadId)
        .eq("organization_id", context.orgId)

      if (error) return safeJson({ ok: false, reason: "write_failed" }, 409)
      await recordAudit(admin, user.id, context.orgId, leadId, "broker_followup_set", {})
      return safeJson({ ok: true, status: "updated" })
    }

    if (action === "update_booking_stage") {
      const stage = safeBookingStage(body.booking_stage)
      const { error } = await admin
        .from("leads_public")
        .update({
          booking_stage: stage,
          conversion_stage: stage === "closed" ? "closed" : stage === "lost" ? "lost" : "booking_discussion",
          updated_at: new Date().toISOString(),
        })
        .eq("id", leadId)
        .eq("organization_id", context.orgId)

      if (error) return safeJson({ ok: false, reason: "write_failed" }, 409)
      await recordAudit(admin, user.id, context.orgId, leadId, "booking_stage_updated", { stage })
      return safeJson({ ok: true, status: "updated" })
    }

    if (action === "update_brokerage_status") {
      const status = safeBrokerageStatus(body.brokerage_status)
      const { error } = await admin
        .from("leads_public")
        .update({ brokerage_status: status, updated_at: new Date().toISOString() })
        .eq("id", leadId)
        .eq("organization_id", context.orgId)

      if (error) return safeJson({ ok: false, reason: "write_failed" }, 409)
      await recordAudit(admin, user.id, context.orgId, leadId, "brokerage_status_updated", { status })
      return safeJson({ ok: true, status: "updated" })
    }

    if (action === "raise_issue") {
      const issueType = cleanText(body.issue_type, 40)
      const safeIssueType = issueTypes.has(issueType) ? issueType : "other"
      const brokerId = validUuid(lead.source_broker_id)
      if (!brokerId) return safeJson({ ok: false, reason: "broker_not_found" }, 404)

      const { error } = await admin.from("broker_issues").insert({
        organization_id: context.orgId,
        broker_id: brokerId,
        lead_id: leadId,
        raised_by: user.id,
        issue_type: safeIssueType,
        notes_safe: safeNotes(body.notes_safe),
      })

      if (error) return safeJson({ ok: false, reason: "write_failed" }, 409)

      await admin
        .from("leads_public")
        .update({ brokerage_status: "disputed", updated_at: new Date().toISOString() })
        .eq("id", leadId)
        .eq("organization_id", context.orgId)

      await recordAudit(admin, user.id, context.orgId, leadId, "broker_issue_raised", { issue_type: safeIssueType })
      return safeJson({ ok: true, status: "updated" })
    }

    return safeJson({ ok: false, reason: "unimplemented_action" }, 501)
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
