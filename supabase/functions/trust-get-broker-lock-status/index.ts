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

async function canReadBroker(admin: Admin, userId: string, orgId: string, brokerId: string) {
  const canManage = await requirePermission(admin, userId, "can_manage_broker_crm", orgId)
  const canViewPayouts = await requirePermission(admin, userId, "can_view_payouts", orgId)
  if (canManage || canViewPayouts) return true

  const { data: linked } = await admin.rpc("is_linked_broker_user", {
    p_broker_id: brokerId,
    p_user_id: userId,
  })
  return linked === true
}

async function resolveBrokerId(admin: Admin, userId: string, orgId: string, requestedBrokerId: string | null) {
  if (requestedBrokerId) {
    const { data: broker } = await admin
      .from("brokers_public")
      .select("id, organization_id")
      .eq("id", requestedBrokerId)
      .eq("organization_id", orgId)
      .maybeSingle()
    if (!broker) return null
    return (await canReadBroker(admin, userId, orgId, requestedBrokerId)) ? requestedBrokerId : null
  }

  const { data: broker } = await admin
    .from("brokers_public")
    .select("id")
    .eq("linked_user_id", userId)
    .eq("organization_id", orgId)
    .maybeSingle()

  return validUuid(broker?.id)
}

function daysRemaining(expiresAt: unknown) {
  if (typeof expiresAt !== "string") return null
  const diff = new Date(expiresAt).getTime() - Date.now()
  if (!Number.isFinite(diff)) return null
  return Math.max(0, Math.ceil(diff / 86400000))
}

function proofStatus(lock: Record<string, unknown>) {
  const metadata = lock.metadata
  if (metadata && typeof metadata === "object" && "proof_status" in metadata) {
    return `${(metadata as Record<string, unknown>).proof_status ?? "unknown"}`
  }
  return lock.source_site_visit_id ? "linked" : "pending"
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
    const requestedBrokerId = validUuid(body.broker_id)

    if (!leadId && !requestedBrokerId) return safeJson({ ok: false, reason: "invalid_input" }, 400)

    let brokerId = requestedBrokerId
    if (leadId) {
      const { data: lead } = await admin
        .from("leads_public")
        .select("id, organization_id, source_broker_id, broker_id, assigned_sourcing_manager_id, assigned_manager_id")
        .eq("id", leadId)
        .eq("organization_id", context.orgId)
        .maybeSingle()

      if (!lead) return safeJson({ ok: false, reason: "not_found_or_forbidden" }, 404)

      const canManage = await requirePermission(admin, user.id, "can_manage_broker_crm", context.orgId)
      const canGrant = await requirePermission(admin, user.id, "can_grant_data_loans", context.orgId)
      const sourceBrokerId = validUuid(lead.source_broker_id)
      const linked = sourceBrokerId ? await canReadBroker(admin, user.id, context.orgId, sourceBrokerId) : false
      const direct =
        lead.broker_id === user.id ||
        lead.assigned_sourcing_manager_id === user.id ||
        lead.assigned_manager_id === user.id
      if (!direct && !canManage && !canGrant && !linked) {
        return safeJson({ ok: false, reason: "not_found_or_forbidden" }, 404)
      }
      brokerId = sourceBrokerId ?? validUuid(lead.broker_id)
    } else {
      brokerId = await resolveBrokerId(admin, user.id, context.orgId, requestedBrokerId)
    }

    if (!brokerId) return safeJson({ ok: false, reason: "not_found_or_forbidden" }, 404)

    let query = admin
      .from("broker_locks")
      .select("id, lead_id, broker_id, status, brokerage_status, expires_at, source_site_visit_id, metadata")
      .eq("broker_id", brokerId)
      .order("expires_at", { ascending: false })
      .limit(10)

    if (leadId) query = query.eq("lead_id", leadId)

    const { data: locks } = await query
    const rows = Array.isArray(locks) ? locks : []
    const active = rows.find((row) => row.status === "active") ?? rows[0]

    return safeJson({
      ok: true,
      lock_status: active?.status ?? "none",
      days_remaining: active ? daysRemaining(active.expires_at) : 0,
      brokerage_status: active?.brokerage_status ?? "not_started",
      proof_status: active ? proofStatus(active) : "none",
      locks: rows.map((row) => ({
        lead_id: row.lead_id,
        lock_status: row.status,
        days_remaining: daysRemaining(row.expires_at),
        brokerage_status: row.brokerage_status ?? "not_started",
        proof_status: proofStatus(row),
      })),
    })
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
