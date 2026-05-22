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

async function canReadLead(admin: Admin, userId: string, orgId: string, leadId: string) {
  const { data: lead } = await admin
    .from("leads_public")
    .select("id, organization_id, source_broker_id, broker_id, assigned_caller_id, assigned_sourcing_manager_id, assigned_manager_id, alias, area, city, property_name, project_id, budget_min, budget_max, lead_status, conversion_stage, project_match_status")
    .eq("id", leadId)
    .eq("organization_id", orgId)
    .maybeSingle()

  if (!lead) return null

  if (
    lead.broker_id === userId ||
    lead.assigned_caller_id === userId ||
    lead.assigned_sourcing_manager_id === userId ||
    lead.assigned_manager_id === userId
  ) {
    return lead
  }

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

function budgetRange(min: unknown, max: unknown) {
  if (min === null && max === null) return null
  if (min === undefined && max === undefined) return null
  const low = Number(min ?? 0)
  const high = Number(max ?? 0)
  if (!Number.isFinite(low) && !Number.isFinite(high)) return null
  return {
    min: Number.isFinite(low) ? low : null,
    max: Number.isFinite(high) ? high : null,
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

    const lead = await canReadLead(admin, user.id, context.orgId, leadId)
    if (!lead) return safeJson({ ok: false, reason: "not_found_or_forbidden" }, 404)

    return safeJson({
      ok: true,
      lead_alias: lead.alias ?? null,
      status: lead.conversion_stage ?? lead.lead_status ?? "unknown",
      budget_range: budgetRange(lead.budget_min, lead.budget_max),
      area: lead.area ?? null,
      project_interest: lead.property_name ?? lead.project_match_status ?? null,
      source_broker_id: lead.source_broker_id ?? null,
    })
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
