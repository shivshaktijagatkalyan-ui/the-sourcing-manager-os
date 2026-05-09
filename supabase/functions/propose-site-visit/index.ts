import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  cleanText,
  corsHeaders,
  currentUser,
  recordAudit,
  safeJson,
  validUuid,
} from "../_shared/sprint7.ts"

const digits = /\d{5,}/g

function safeNotes(value: unknown) {
  const cleaned = cleanText(value, 500)
  return digits.test(cleaned) ? "[CLEANED]" : cleaned
}

function safeDate(value: unknown) {
  if (typeof value !== "string") return null
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString()
}

async function actorContext(admin: ReturnType<typeof adminClient>, userId: string) {
  const { data } = await admin
    .from("pilot_users")
    .select("org_id, status, organizations(status)")
    .eq("user_id", userId)
    .maybeSingle()

  if (!data || data.status !== "active" || data.organizations?.status !== "active") return null
  return { organization_id: data.org_id as string }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: "unauthorized" }, 401)

    const admin = adminClient()
    const context = await actorContext(admin, user.id)
    if (!context) return safeJson({ ok: false, reason: "access_blocked" }, 403)

    const body = await req.json().catch(() => ({}))
    const leadId = validUuid(body.lead_id)
    const projectId = validUuid(body.project_id)
    const proposedFor = safeDate(body.proposed_for ?? body.proposed_at)

    if (!leadId || !projectId || !proposedFor) {
      return safeJson({ ok: false, reason: "invalid_input" }, 400)
    }

    const { data: broker } = await admin
      .from("brokers_public")
      .select("id, organization_id, linked_user_id, assigned_sourcing_manager_id, status")
      .eq("linked_user_id", user.id)
      .eq("organization_id", context.organization_id)
      .eq("status", "active")
      .maybeSingle()

    if (!broker) return safeJson({ ok: false, reason: "broker_not_found" }, 404)

    const { data: lead } = await admin
      .from("leads_public")
      .select("id, organization_id, source_broker_id, assigned_sourcing_manager_id, assigned_manager_id, project_id")
      .eq("id", leadId)
      .eq("organization_id", context.organization_id)
      .eq("source_broker_id", broker.id)
      .maybeSingle()

    if (!lead) return safeJson({ ok: false, reason: "lead_not_found" }, 404)

    const { data: project } = await admin
      .from("projects")
      .select("id, organization_id, status")
      .eq("id", projectId)
      .eq("status", "active")
      .maybeSingle()

    if (!project || (project.organization_id && project.organization_id !== context.organization_id)) {
      return safeJson({ ok: false, reason: "project_not_allowed" }, 403)
    }

    const { data: activation } = await admin
      .from("broker_activations")
      .select("assigned_sourcing_manager_id")
      .eq("organization_id", context.organization_id)
      .eq("broker_id", broker.id)
      .eq("project_id", projectId)
      .maybeSingle()

    const managerId =
      validUuid(lead.assigned_sourcing_manager_id) ??
      validUuid(lead.assigned_manager_id) ??
      validUuid(activation?.assigned_sourcing_manager_id) ??
      validUuid(broker.assigned_sourcing_manager_id)

    if (!managerId) return safeJson({ ok: false, reason: "manager_not_assigned" }, 409)

    const { error } = await admin.from("site_visit_proposals").insert({
      organization_id: context.organization_id,
      source_broker_id: broker.id,
      source_lead_id: leadId,
      project_id: projectId,
      assigned_sourcing_manager_id: managerId,
      proposed_by: user.id,
      status: "proposed",
      proposed_for: proposedFor,
      notes_safe: safeNotes(body.notes_safe ?? body.notes),
    })

    if (error) return safeJson({ ok: false, reason: "write_blocked" }, 409)

    await admin
      .from("leads_public")
      .update({ conversion_stage: "visit_proposed", updated_at: new Date().toISOString() })
      .eq("id", leadId)
      .eq("organization_id", context.organization_id)

    await recordAudit(admin, user.id, context.organization_id, null, "site_visit_proposed", {
      lead_id: leadId,
      project_id: projectId,
      source_broker_id: broker.id,
      status: "proposed",
      organization_id: context.organization_id,
    })

    return safeJson({ ok: true, status: "proposed" })
  } catch (_) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
