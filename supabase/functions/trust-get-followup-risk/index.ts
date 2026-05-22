import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  corsHeaders,
  currentUser,
  requirePermission,
  safeJson,
  validUuid,
} from "../_shared/sprint7.ts"

type Admin = ReturnType<typeof adminClient>

async function actorContext(admin: Admin, userId: string) {
  const { data } = await admin
    .from("pilot_users")
    .select("org_id, status, organizations(status)")
    .eq("user_id", userId)
    .maybeSingle()

  if (!data || data.status !== "active" || data.organizations?.status !== "active") return null
  return { orgId: data.org_id as string }
}

async function readableLead(admin: Admin, userId: string, orgId: string, leadId: string) {
  const { data: lead } = await admin
    .from("leads_public")
    .select("id, organization_id, source_broker_id, broker_id, assigned_caller_id, assigned_sourcing_manager_id, assigned_manager_id, lead_status, conversion_stage, last_call_outcome, next_followup_at, lead_quality, created_at, updated_at")
    .eq("id", leadId)
    .eq("organization_id", orgId)
    .maybeSingle()

  if (!lead) return null
  if (
    lead.broker_id === userId ||
    lead.assigned_caller_id === userId ||
    lead.assigned_sourcing_manager_id === userId ||
    lead.assigned_manager_id === userId
  ) return lead

  const canManage = await requirePermission(admin, userId, "can_manage_broker_crm", orgId)
  const canGrant = await requirePermission(admin, userId, "can_grant_data_loans", orgId)
  if (canManage || canGrant) return lead

  const sourceBrokerId = validUuid(lead.source_broker_id)
  if (!sourceBrokerId) return null
  const { data: linked } = await admin.rpc("is_linked_broker_user", {
    p_broker_id: sourceBrokerId,
    p_user_id: userId,
  })
  return linked === true ? lead : null
}

function riskFor(lead: Record<string, unknown>) {
  const nextFollowup = typeof lead.next_followup_at === "string" ? new Date(lead.next_followup_at) : null
  const now = Date.now()
  const delayHours = nextFollowup && Number.isFinite(nextFollowup.getTime())
    ? Math.floor((now - nextFollowup.getTime()) / 3600000)
    : null
  const status = `${lead.conversion_stage ?? lead.lead_status ?? ""}`
  const quality = `${lead.lead_quality ?? ""}`

  if (["visit_verified", "locked", "closed"].includes(status)) {
    return { followup_delay: delayHours, risk_level: "low", next_action: "monitor_lock" }
  }
  if (delayHours !== null && delayHours >= 24) {
    return { followup_delay: delayHours, risk_level: "high", next_action: "create_followup" }
  }
  if (delayHours !== null && delayHours >= 2) {
    return { followup_delay: delayHours, risk_level: "medium", next_action: "call_or_reschedule" }
  }
  if (quality === "hot" || status === "interested") {
    return { followup_delay: delayHours, risk_level: "medium", next_action: "schedule_visit" }
  }
  return { followup_delay: delayHours, risk_level: "low", next_action: "wait" }
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
    if (!leadId) return safeJson({ ok: false, reason: "invalid_input" }, 400)

    const lead = await readableLead(admin, user.id, context.orgId, leadId)
    if (!lead) return safeJson({ ok: false, reason: "not_found_or_forbidden" }, 404)

    return safeJson({ ok: true, ...riskFor(lead) })
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
