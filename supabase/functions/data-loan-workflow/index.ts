import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  corsHeaders,
  currentUser,
  requirePermission,
  safeJson,
  validUuid,
  recordAudit,
} from "../_shared/sprint7.ts"

const actions = new Set(["grant_access", "revoke_access", "extend_access"])
const purposes = new Set(["call", "site_visit"])

function safePurpose(value: unknown) {
  const purpose = typeof value === "string" ? value : "call"
  return purposes.has(purpose) ? purpose : null
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

async function leadAccess(admin: ReturnType<typeof adminClient>, userId: string, orgId: string, leadId: string) {
  const { data: lead } = await admin
    .from("leads_public")
    .select("id, organization_id, source_broker_id, broker_id")
    .eq("id", leadId)
    .eq("organization_id", orgId)
    .maybeSingle()

  if (!lead) return null

  const canGrant = await requirePermission(admin, userId, "can_grant_data_loans", orgId)
  const canManage = await requirePermission(admin, userId, "can_manage_broker_crm", orgId)
  if (canGrant || canManage || lead.broker_id === userId) return lead

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

    const leadId = validUuid(body.lead_id)
    if (!leadId) return safeJson({ ok: false, reason: "invalid_lead" }, 400)
    const purpose = safePurpose(body.purpose)
    if (!purpose) return safeJson({ ok: false, reason: "invalid_purpose" }, 400)

    const lead = await leadAccess(admin, user.id, context.orgId, leadId)
    if (!lead) return safeJson({ ok: false, reason: "forbidden" }, 403)

    if (action === "grant_access") {
      const granteeId = validUuid(body.granted_to_user_id)
      if (!granteeId) return safeJson({ ok: false, reason: "grantee_required" }, 400)

      const { data: grantee } = await admin
        .from("pilot_users")
        .select("user_id")
        .eq("user_id", granteeId)
        .eq("org_id", context.orgId)
        .eq("status", "active")
        .maybeSingle()

      if (!grantee) return safeJson({ ok: false, reason: "grantee_not_active" }, 404)

      await admin
        .from("data_loans")
        .update({ status: "revoked", revoked_at: new Date().toISOString(), revoked_by: user.id })
        .eq("lead_id", leadId)
        .eq("purpose", purpose)
        .eq("status", "active")

      const startsAt = new Date()
      const expiresAt = new Date(startsAt.getTime() + Number(body.duration_hours ?? 24) * 60 * 60 * 1000)
      const { error } = await admin.from("data_loans").insert({
        lead_id: leadId,
        broker_id: lead.broker_id,
        granted_to_user_id: granteeId,
        purpose: purpose,
        status: "active",
        starts_at: startsAt.toISOString(),
        expires_at: expiresAt.toISOString(),
      })

      if (error) return safeJson({ ok: false, reason: "write_failed" }, 409)

      if (purpose === "call") {
        await admin
          .from("leads_public")
          .update({
            assigned_caller_id: granteeId,
            conversion_stage: "assigned_to_caller",
            updated_at: new Date().toISOString(),
          })
          .eq("id", leadId)
          .eq("organization_id", context.orgId)
      }

      await recordAudit(admin, user.id, context.orgId, leadId, "data_loan_granted", { grantee_id: granteeId, purpose })
      return safeJson({ ok: true, status: "updated" })
    }

    const requestedLoanId = validUuid(body.loan_id)
    let loanQuery = admin
      .from("data_loans")
      .select("id, expires_at")
      .eq("lead_id", leadId)
      .eq("purpose", purpose)
      .eq("status", "active")

    if (requestedLoanId) {
      loanQuery = loanQuery.eq("id", requestedLoanId)
    } else {
      loanQuery = loanQuery.order("created_at", { ascending: false }).limit(1)
    }

    const { data: loan } = await loanQuery.maybeSingle()

    if (!loan) return safeJson({ ok: false, reason: "active_access_not_found" }, 404)

    if (action === "revoke_access") {
      const { error } = await admin
        .from("data_loans")
        .update({ status: "revoked", revoked_at: new Date().toISOString(), revoked_by: user.id })
        .eq("id", loan.id)

      if (error) return safeJson({ ok: false, reason: "write_failed" }, 409)
      await recordAudit(admin, user.id, context.orgId, leadId, "data_loan_revoked", { purpose, loan_id: loan.id })
      return safeJson({ ok: true, status: "updated" })
    }

    if (action === "extend_access") {
      const base = new Date(loan.expires_at)
      const now = new Date()
      const start = base > now ? base : now
      const nextExpiry = new Date(start.getTime() + Number(body.duration_hours ?? 24) * 60 * 60 * 1000)
      const { error } = await admin
        .from("data_loans")
        .update({ expires_at: nextExpiry.toISOString() })
        .eq("id", loan.id)

      if (error) return safeJson({ ok: false, reason: "write_failed" }, 409)
      await recordAudit(admin, user.id, context.orgId, leadId, "data_loan_extended", { purpose, loan_id: loan.id })
      return safeJson({ ok: true, status: "updated" })
    }

    return safeJson({ ok: false, reason: "unimplemented_action" }, 501)
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
