import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  cleanText,
  corsHeaders,
  currentUser,
  recordAudit,
  requirePermission,
  safeJson,
  sha256,
  validUuid,
} from "../_shared/sprint7.ts"

const actions = new Set(["accept", "reschedule", "reject"])
const digits = /\d{5,}/g

function safeNotes(value: unknown) {
  const cleaned = cleanText(value, 500)
  return digits.test(cleaned) ? "[CLEANED]" : cleaned
}

function safeDate(value: unknown, fallback: string) {
  if (typeof value !== "string") return fallback
  const parsed = new Date(value)
  return Number.isNaN(parsed.getTime()) ? fallback : parsed.toISOString()
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
    const proposalId = validUuid(body.proposal_id)
    const action = typeof body.action === "string" ? body.action : ""
    if (!proposalId || !actions.has(action)) return safeJson({ ok: false, reason: "invalid_input" }, 400)

    const { data: proposal } = await admin
      .from("site_visit_proposals")
      .select("id, organization_id, source_broker_id, source_lead_id, project_id, assigned_sourcing_manager_id, proposed_by, proposed_for, status")
      .eq("id", proposalId)
      .eq("organization_id", context.organization_id)
      .maybeSingle()

    if (!proposal || proposal.status === "rejected" || proposal.status === "cancelled") {
      return safeJson({ ok: false, reason: "proposal_not_available" }, 404)
    }

    const canManage = await requirePermission(admin, user.id, "can_create_site_visits", context.organization_id)
    if (proposal.assigned_sourcing_manager_id !== user.id && !canManage) {
      return safeJson({ ok: false, reason: "not_allowed" }, 403)
    }

    if (action === "reject") {
      await admin
        .from("site_visit_proposals")
        .update({
          status: "rejected",
          reviewed_by: user.id,
          rejected_at: new Date().toISOString(),
          review_notes_safe: safeNotes(body.notes_safe ?? body.notes),
        })
        .eq("id", proposalId)
        .eq("organization_id", context.organization_id)

      await recordAudit(admin, user.id, context.organization_id, null, "site_visit_rejected", {
        proposal_id: proposalId,
        lead_id: proposal.source_lead_id,
        project_id: proposal.project_id,
        source_broker_id: proposal.source_broker_id,
        status: "rejected",
        organization_id: context.organization_id,
      })

      return safeJson({ ok: true, status: "rejected" })
    }

    const scheduledAt = safeDate(body.scheduled_at, proposal.proposed_for)

    const { data: lead } = await admin
      .from("leads_public")
      .select("id, broker_id, organization_id, property_name, area, city")
      .eq("id", proposal.source_lead_id)
      .eq("organization_id", context.organization_id)
      .maybeSingle()

    const { data: project } = await admin
      .from("projects")
      .select("id, project_name, area, city")
      .eq("id", proposal.project_id)
      .maybeSingle()

    if (!lead || !project) return safeJson({ ok: false, reason: "safe_record_missing" }, 404)

    const codeSeed = `${proposalId}:${user.id}:${scheduledAt}`
    const codeHash = await sha256(codeSeed)
    const updateStatus = action === "reschedule" ? "scheduled" : "accepted"

    await admin
      .from("site_visit_proposals")
      .update({
        status: updateStatus,
        reviewed_by: user.id,
        accepted_at: new Date().toISOString(),
        scheduled_at: scheduledAt,
        review_notes_safe: safeNotes(body.notes_safe ?? body.notes),
      })
      .eq("id", proposalId)
      .eq("organization_id", context.organization_id)

    const { data: existing } = await admin
      .from("site_visits")
      .select("id")
      .eq("proposal_id", proposalId)
      .maybeSingle()

    const visitPayload = {
      organization_id: context.organization_id,
      lead_id: proposal.source_lead_id,
      source_lead_id: proposal.source_lead_id,
      broker_id: lead.broker_id ?? proposal.proposed_by,
      source_broker_id: proposal.source_broker_id,
      sourcing_manager_id: user.id,
      project_id: proposal.project_id,
      proposal_id: proposalId,
      property_name: lead.property_name || project.project_name,
      area: project.area || lead.area,
      city: project.city || lead.city,
      visit_date: scheduledAt,
      scheduled_at: scheduledAt,
      status: "scheduled",
      visit_code_hash: codeHash,
      qr_code_hash: await sha256(`${codeHash}:qr`),
      proof_status: "pending",
      updated_at: new Date().toISOString(),
    }

    if (existing?.id) {
      await admin
        .from("site_visits")
        .update(visitPayload)
        .eq("id", existing.id)
        .eq("organization_id", context.organization_id)
    } else {
      await admin.from("site_visits").insert({ ...visitPayload, created_at: new Date().toISOString() })
    }

    await admin
      .from("leads_public")
      .update({
        lead_status: "visit_scheduled",
        conversion_stage: "visit_scheduled",
        booking_stage: "booking_discussion",
        brokerage_status: "pending_visit",
        updated_at: new Date().toISOString(),
      })
      .eq("id", proposal.source_lead_id)
      .eq("organization_id", context.organization_id)

    await recordAudit(admin, user.id, context.organization_id, null, "site_visit_accepted", {
      proposal_id: proposalId,
      lead_id: proposal.source_lead_id,
      project_id: proposal.project_id,
      source_broker_id: proposal.source_broker_id,
      status: updateStatus,
      organization_id: context.organization_id,
    })

    await recordAudit(admin, user.id, context.organization_id, null, "site_visit_scheduled", {
      proposal_id: proposalId,
      lead_id: proposal.source_lead_id,
      project_id: proposal.project_id,
      source_broker_id: proposal.source_broker_id,
      status: "scheduled",
      organization_id: context.organization_id,
    })

    return safeJson({ ok: true, status: "scheduled" })
  } catch (_) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
