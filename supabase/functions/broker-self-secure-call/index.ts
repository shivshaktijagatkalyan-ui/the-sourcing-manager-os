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
) {
  await admin.from("call_attempts").insert({
    lead_id: leadId,
    caller_id: userId,
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

    if (lead.lead_status === "revoked") {
      await blockAttempt(admin, user.id, context.orgId, leadId, "revoked")
      return safeJson({ ok: false, reason: "revoked" }, 403)
    }

    if (lead.consent_status !== "granted") {
      await blockAttempt(admin, user.id, context.orgId, leadId, "consent_required")
      return safeJson({ ok: false, reason: "consent_required" }, 403)
    }

    if (lead.dnd_status === "blocked") {
      await blockAttempt(admin, user.id, context.orgId, leadId, "dnd_blocked")
      return safeJson({ ok: false, reason: "dnd_blocked" }, 403)
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
        provider: "exotel",
        call_status: "connecting",
      })
      .select("id")
      .single()

    if (attemptError || !attempt) return safeJson({ ok: false, reason: "write_failed" }, 409)

    const sid = Deno.env.get("EXOTEL_SID") ?? ""
    const apiKey = Deno.env.get("EXOTEL_API_KEY") ?? ""
    const apiToken = Deno.env.get("EXOTEL_API_TOKEN") ?? ""
    const subdomain = Deno.env.get("EXOTEL_SUBDOMAIN") || "api.in.exotel.com"
    const callerId = Deno.env.get("EXOTEL_CALLER_ID") ?? ""
    const bridgeEndpoint = `https://${subdomain}/v1/Accounts/${sid}/Calls/connect.json`
    const callbackUrl = `${Deno.env.get("SUPABASE_URL")}/functions/v1/exotel-callback?attempt_id=${attempt.id}`

    bridgeBody = new URLSearchParams()
    bridgeBody.append("From", callerId)
    bridgeBody.append("To", destination)
    bridgeBody.append("CallerId", callerId)
    bridgeBody.append("StatusCallback", callbackUrl)

    const bridgeResponse = await fetch(bridgeEndpoint, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${apiKey}:${apiToken}`)}`,
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
