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
    .select("id, organization_id, source_broker_id, broker_id, assigned_caller_id, assigned_sourcing_manager_id, assigned_manager_id, lead_status, conversion_stage, last_call_outcome, next_followup_at, lead_quality, brokerage_status, created_at, updated_at")
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
  const canCreateVisits = await requirePermission(admin, userId, "can_create_site_visits", orgId)
  if (canManage || canGrant || canCreateVisits) return lead

  const sourceBrokerId = validUuid(lead.source_broker_id)
  if (!sourceBrokerId) return null
  const { data: linked } = await admin.rpc("is_linked_broker_user", {
    p_broker_id: sourceBrokerId,
    p_user_id: userId,
  })
  return linked === true ? lead : null
}

async function latestVisit(admin: Admin, leadId: string, orgId: string) {
  const { data } = await admin
    .from("site_visits")
    .select("id, status, proof_status, updated_at")
    .eq("organization_id", orgId)
    .or(`lead_id.eq.${leadId},source_lead_id.eq.${leadId}`)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle()

  return data
}

async function activeLock(admin: Admin, leadId: string) {
  const { data } = await admin
    .from("broker_locks")
    .select("id, status, brokerage_status, expires_at")
    .eq("lead_id", leadId)
    .eq("status", "active")
    .maybeSingle()

  return data
}

function overdueHours(value: unknown) {
  if (typeof value !== "string") return null
  const parsed = new Date(value).getTime()
  if (!Number.isFinite(parsed)) return null
  return Math.floor((Date.now() - parsed) / 3600000)
}

function recommendation(lead: Record<string, unknown>, visit: Record<string, unknown> | null, lock: Record<string, unknown> | null) {
  const stage = `${lead.conversion_stage ?? lead.lead_status ?? ""}`
  const outcome = `${lead.last_call_outcome ?? ""}`
  const quality = `${lead.lead_quality ?? ""}`
  const delay = overdueHours(lead.next_followup_at)

  if (lock?.status === "active") {
    return {
      recommended_action: "monitor_lock",
      reason: "active broker lock exists",
      risk: lock.brokerage_status === "disputed" ? "high" : "low",
      confidence: 0.92,
    }
  }

  if (visit && ["started", "gps_verified", "qr_verified", "photo_uploaded"].includes(`${visit.status}`)) {
    return {
      recommended_action: "verify_site_visit",
      reason: "site visit proof is incomplete",
      risk: "high",
      confidence: 0.9,
    }
  }

  if (["interested", "site_visit_ready"].includes(stage) || outcome === "interested" || quality === "hot") {
    return {
      recommended_action: "schedule_visit",
      reason: "lead metadata indicates visit readiness",
      risk: "medium",
      confidence: 0.82,
    }
  }

  if (delay !== null && delay >= 2) {
    return {
      recommended_action: "call_now",
      reason: "follow-up window is delayed",
      risk: delay >= 24 ? "high" : "medium",
      confidence: 0.86,
    }
  }

  if (["wrong_lead", "budget_mismatch", "location_mismatch", "not_interested"].includes(stage) || outcome === "not_interested") {
    return {
      recommended_action: "resolve_blocker",
      reason: "lead is blocked by negative workflow state",
      risk: "medium",
      confidence: 0.78,
    }
  }

  return {
    recommended_action: "wait",
    reason: "no urgent workflow risk detected",
    risk: "low",
    confidence: 0.74,
  }
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

    const visit = await latestVisit(admin, leadId, context.orgId)
    const lock = await activeLock(admin, leadId)

    return safeJson({ ok: true, ...recommendation(lead, visit, lock) })
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
