import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  cleanText,
  corsHeaders,
  currentUser,
  requirePermission,
  safeJson,
  validUuid,
} from "../_shared/sprint7.ts"

type Admin = ReturnType<typeof adminClient>

const followupTypes = new Set(["call", "visit", "document", "brokerage", "general"])
const priorities = new Set(["low", "normal", "high", "urgent"])
const restrictedDigitSequence = /\d{5,}/

function safeType(value: unknown) {
  const cleaned = cleanText(value, 40).toLowerCase()
  return followupTypes.has(cleaned) ? cleaned : "general"
}

function safePriority(value: unknown) {
  const cleaned = cleanText(value, 20).toLowerCase()
  return priorities.has(cleaned) ? cleaned : "normal"
}

function safeReason(value: unknown) {
  const cleaned = cleanText(value, 240)
  return restrictedDigitSequence.test(cleaned) ? "[CLEANED]" : cleaned
}

function safeDate(value: unknown) {
  if (typeof value !== "string") return null
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString()
}

async function actorContext(admin: Admin, userId: string) {
  const { data } = await admin
    .from("pilot_users")
    .select("org_id, status, organizations(status)")
    .eq("user_id", userId)
    .maybeSingle()

  if (!data || data.status !== "active" || data.organizations?.status !== "active") return null
  return { orgId: data.org_id as string }
}

async function writableLead(admin: Admin, userId: string, orgId: string, leadId: string) {
  const { data: lead } = await admin
    .from("leads_public")
    .select("id, organization_id, source_broker_id, broker_id, assigned_caller_id, assigned_sourcing_manager_id, assigned_manager_id, project_id")
    .eq("id", leadId)
    .eq("organization_id", orgId)
    .maybeSingle()

  if (!lead) return null
  const canManage = await requirePermission(admin, userId, "can_manage_broker_crm", orgId)
  const canGrant = await requirePermission(admin, userId, "can_grant_data_loans", orgId)
  if (
    canManage ||
    canGrant ||
    lead.broker_id === userId ||
    lead.assigned_caller_id === userId ||
    lead.assigned_sourcing_manager_id === userId ||
    lead.assigned_manager_id === userId
  ) return lead

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
    const leadId = validUuid(body.lead_id)
    const dueAt = safeDate(body.due_at)
    if (!leadId || !dueAt) return safeJson({ ok: false, reason: "invalid_input" }, 400)

    const lead = await writableLead(admin, user.id, context.orgId, leadId)
    if (!lead) return safeJson({ ok: false, reason: "not_found_or_forbidden" }, 404)

    const brokerId = validUuid(lead.source_broker_id) ?? validUuid(lead.broker_id)
    if (!brokerId) return safeJson({ ok: false, reason: "broker_not_found" }, 404)

    const assignedTo =
      validUuid(lead.assigned_sourcing_manager_id) ??
      validUuid(lead.assigned_manager_id) ??
      validUuid(lead.assigned_caller_id) ??
      user.id
    const followupType = safeType(body.followup_type)
    const reason = safeReason(body.reason)

    const { data: followup, error: followupError } = await admin
      .from("broker_followups")
      .insert({
        organization_id: context.orgId,
        broker_id: brokerId,
        project_id: validUuid(lead.project_id),
        assigned_to: assignedTo,
        due_at: dueAt,
        priority: safePriority(body.priority),
        status: "pending",
        reason: `${followupType}:${reason || "workflow_followup"}`,
      })
      .select("id")
      .single()

    if (followupError || !followup) return safeJson({ ok: false, reason: "write_failed" }, 409)

    await admin
      .from("leads_public")
      .update({ next_followup_at: dueAt, updated_at: new Date().toISOString() })
      .eq("id", leadId)
      .eq("organization_id", context.orgId)

    const { data: audit } = await admin
      .from("audit_events")
      .insert({
        actor_id: user.id,
        lead_id: leadId,
        event_type: "trust_followup_created",
        event_context: {
          organization_id: context.orgId,
          followup_id: followup.id,
          followup_type: followupType,
          due_at: dueAt,
        },
      })
      .select("id")
      .maybeSingle()

    return safeJson({
      ok: true,
      success: true,
      followup_id: followup.id,
      audit_event_id: audit?.id ?? null,
    })
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
