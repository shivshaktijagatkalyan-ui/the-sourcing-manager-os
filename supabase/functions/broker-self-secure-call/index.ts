import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  corsHeaders,
  currentUser,
  requirePermission,
  safeJson,
  validUuid,
  recordAudit,
  hmacSha256,
} from "../_shared/sprint7.ts"

function providerConfig() {
  const config = {
    sid: Deno.env.get("EXOTEL_SID") ?? "",
    apiKey: Deno.env.get("EXOTEL_API_KEY") ?? "",
    apiToken: Deno.env.get("EXOTEL_API_TOKEN") ?? "",
    callerId: Deno.env.get("EXOTEL_CALLER_ID") ?? "",
    callbackSecret: Deno.env.get("EXOTEL_CALLBACK_SECRET") ?? "",
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    subdomain: Deno.env.get("EXOTEL_SUBDOMAIN") || "api.in.exotel.com",
  }

  const missing = Object.entries(config)
    .filter(([key, value]) => key !== "subdomain" && !value)
    .map(([key]) => key)

  return missing.length > 0 ? { ok: false as const, missing } : { ok: true as const, config }
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

async function canCallLead(admin: ReturnType<typeof adminClient>, userId: string, orgId: string, leadId: string) {
  const { data: lead } = await admin
    .from("leads_public")
    .select("id, organization_id, source_broker_id, broker_id, consent_status, dnd_status, lead_status")
    .eq("id", leadId)
    .eq("organization_id", orgId)
    .maybeSingle()

  if (!lead) return null

  const allowed = await requirePermission(admin, userId, "can_call_leads", orgId)
  if (allowed || lead.broker_id === userId) return lead

  const sourceBrokerId = validUuid(lead.source_broker_id)
  if (!sourceBrokerId) return null

  const { data: linked } = await admin.rpc("is_linked_broker_user", {
    p_broker_id: sourceBrokerId,
    p_user_id: userId,
  })

  return linked === true ? lead : null
}

async function blockAttempt(
  admin: ReturnType<typeof adminClient>,
  userId: string,
  orgId: string,
  leadId: string,
  status: string,
  loanId?: string,
) {
  await admin.from("call_attempts").insert({
    lead_id: leadId,
    caller_id: userId,
    data_loan_id: loanId ?? null,
    provider: "exotel",
    call_status: status,
  })

  await recordAudit(admin, userId, orgId, leadId, "broker_self_call_blocked", { reason: status })
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405)

  let destination: string | null = null
  let bridgeBody: URLSearchParams | null = null

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: "unauthorized" }, 401)

    const admin = adminClient()
    const context = await actorContext(admin, user.id)
    if (!context) return safeJson({ ok: false, reason: "access_blocked_operational" }, 403)

    const body = await req.json().catch(() => ({}))
    const leadId = validUuid(body.lead_id)
    if (!leadId || Object.keys(body).some((key) => !["lead_id"].includes(key))) {
      return safeJson({ ok: false, reason: "invalid_input" }, 400)
    }

    const lead = await canCallLead(admin, user.id, context.orgId, leadId)
    if (!lead) return safeJson({ ok: false, reason: "forbidden" }, 403)

    const { data: loans, error: loanError } = await admin
      .from("data_loans")
      .select("id, status, starts_at, expires_at, revoked_at")
      .eq("lead_id", leadId)
      .eq("granted_to_user_id", user.id)
      .eq("purpose", "call")
      .order("created_at", { ascending: false })
      .limit(1)

    if (loanError) return safeJson({ ok: false, reason: "loan_fetch_failed" }, 409)

    const loan = Array.isArray(loans) ? loans[0] : null
    const nowMs = Date.now()
    if (!loan) {
      await blockAttempt(admin, user.id, context.orgId, leadId, "blocked")
      return safeJson({ ok: false, reason: "access_denied" }, 403)
    }
    if (loan.status === "revoked" || loan.revoked_at) {
      await blockAttempt(admin, user.id, context.orgId, leadId, "revoked", loan.id)
      return safeJson({ ok: false, reason: "revoked" }, 403)
    }
    if (loan.status !== "active" || new Date(loan.starts_at).getTime() > nowMs || new Date(loan.expires_at).getTime() <= nowMs) {
      await blockAttempt(admin, user.id, context.orgId, leadId, "expired", loan.id)
      return safeJson({ ok: false, reason: "loan_expired" }, 403)
    }

    if (lead.lead_status === "revoked") {
      await blockAttempt(admin, user.id, context.orgId, leadId, "revoked")
      return safeJson({ ok: false, reason: "revoked" }, 403)
    }

    if (lead.consent_status !== "granted") {
      await blockAttempt(admin, user.id, context.orgId, leadId, "consent_required", loan.id)
      return safeJson({ ok: false, reason: "consent_required" }, 403)
    }

    if (lead.dnd_status === "blocked") {
      await blockAttempt(admin, user.id, context.orgId, leadId, "dnd_blocked", loan.id)
      return safeJson({ ok: false, reason: "dnd_blocked" }, 403)
    }

    const exotel = providerConfig()
    if (!exotel.ok) {
      await blockAttempt(admin, user.id, context.orgId, leadId, "config_error", loan.id)
      await recordAudit(admin, user.id, context.orgId, leadId, "broker_self_call_provider_config_missing", {
        provider: "exotel",
        missing: exotel.missing,
      })
      return safeJson({ ok: false, reason: "provider_config_missing" }, 503)
    }

    const { data: sensitive } = await admin
      .from("leads_sensitive")
      .select("phone_ciphertext")
      .eq("lead_id", leadId)
      .maybeSingle()

    if (!sensitive?.phone_ciphertext) return safeJson({ ok: false, reason: "secure_value_missing" }, 404)

    const { data: clearValue, error: decryptError } = await admin.rpc("decrypt_lead_contact_for_edge", {
      p_ciphertext: sensitive.phone_ciphertext,
      p_key: Deno.env.get("PHONE_ENCRYPTION_KEY") ?? "",
    })

    if (decryptError || typeof clearValue !== "string" || !clearValue) {
      return safeJson({ ok: false, reason: "secure_value_unavailable" }, 409)
    }

    destination = clearValue

    const { data: attempt, error: attemptError } = await admin
      .from("call_attempts")
      .insert({
        lead_id: leadId,
        caller_id: user.id,
        data_loan_id: loan.id,
        provider: "exotel",
        call_status: "connecting",
      })
      .select("id")
      .single()

    if (attemptError || !attempt) return safeJson({ ok: false, reason: "write_failed" }, 409)

    const token = await hmacSha256(attempt.id, exotel.config.callbackSecret)
    const bridgeEndpoint = `https://${exotel.config.subdomain}/v1/Accounts/${exotel.config.sid}/Calls/connect.json`
    const callbackUrl = `${exotel.config.supabaseUrl}/functions/v1/exotel-callback?attempt_id=${attempt.id}&callback_token=${token}`

    bridgeBody = new URLSearchParams()
    bridgeBody.append("From", exotel.config.callerId)
    bridgeBody.append("To", destination)
    bridgeBody.append("CallerId", exotel.config.callerId)
    bridgeBody.append("StatusCallback", callbackUrl)

    const bridgeResponse = await fetch(bridgeEndpoint, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${exotel.config.apiKey}:${exotel.config.apiToken}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: bridgeBody,
    })

    if (!bridgeResponse.ok) {
      await admin.from("call_attempts").update({ call_status: "provider_failed" }).eq("id", attempt.id)
      await recordAudit(admin, user.id, context.orgId, leadId, "broker_self_call_provider_failed", { provider: "exotel" })
      return safeJson({ ok: false, reason: "provider_failed" }, 502)
    }

    await admin.from("call_attempts").update({ call_status: "queued" }).eq("id", attempt.id)
    await recordAudit(admin, user.id, context.orgId, leadId, "broker_self_call_queued", { provider: "exotel", attempt_id: attempt.id })
    return safeJson({ ok: true, status: "queued" })
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  } finally {
    destination = null
    if (bridgeBody) bridgeBody.set("To", "")
    bridgeBody = null
  }
})
