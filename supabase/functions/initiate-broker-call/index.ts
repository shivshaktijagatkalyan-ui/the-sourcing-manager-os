// Practical MVP v0.1: initiate-broker-call
// Secure PSTN call bridge for external brokers without exposing PII.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { adminClient, currentUser, requirePermission, safeJson, validUuid, recordAudit } from "../_shared/sprint7.ts"

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } })
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405)

  let destination: string | null = null;
  let bridgeBody: URLSearchParams | null = null;

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: "unauthorized" }, 401)

    const admin = adminClient()
    const body = await req.json()
    const { broker_id, project_id } = body

    const bId = validUuid(broker_id)
    if (!bId) return safeJson({ ok: false, reason: "invalid_input" }, 400)

    // 1. Fetch Broker Context
    const { data: broker, error: brokerError } = await admin
      .from('brokers_public')
      .select('organization_id, assigned_sourcing_manager_id')
      .eq('id', bId)
      .single()

    if (brokerError || !broker) {
      return safeJson({ ok: false, reason: "broker_not_found" }, 404)
    }

    const orgId = broker.organization_id

    // 2. Fetch Pilot Context
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('status, organizations(status)')
      .eq('user_id', user.id)
      .eq('org_id', orgId)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    // 3. Permission Check
    const isAdmin = await requirePermission(admin, user.id, 'can_manage_broker_crm', orgId)
    const isAssigned = broker.assigned_sourcing_manager_id === user.id

    if (!isAdmin && !isAssigned) {
      return safeJson({ ok: false, reason: "forbidden_permission_required" }, 403)
    }

    // 4. Fetch Secure PII
    const { data: sensitive, error: sensitiveError } = await admin
      .from("brokers_sensitive")
      .select("phone_ciphertext")
      .eq("broker_id", bId)
      .single()

    if (sensitiveError || !sensitive?.phone_ciphertext) {
      return safeJson({ ok: false, reason: "contact_not_available" }, 404)
    }

    const encryptionKey = Deno.env.get("PHONE_ENCRYPTION_KEY") || ""
    const { data: clearValue, error: decryptError } = await admin.rpc("decrypt_lead_contact_for_edge", {
      p_ciphertext: sensitive.phone_ciphertext,
      p_key: encryptionKey
    })

    if (decryptError || typeof clearValue !== "string" || !clearValue) {
      throw new Error('decryption_failed')
    }

    destination = clearValue

    // 5. Provider Bridge (Exotel)
    const sid = Deno.env.get("EXOTEL_SID") ?? ""
    const apiKey = Deno.env.get("EXOTEL_API_KEY") ?? ""
    const apiToken = Deno.env.get("EXOTEL_API_TOKEN") ?? ""
    const subdomain = Deno.env.get("EXOTEL_SUBDOMAIN") || "api.in.exotel.com"
    const bridgeEndpoint = `https://${subdomain}/v1/Accounts/${sid}/Calls/connect.json`
    const callerId = Deno.env.get("EXOTEL_CALLER_ID") ?? ""
    
    // Note: In a real PSTN bridge, we'd also provide a callback for duration tracking
    // For MVP, we log the attempt immediately.

    bridgeBody = new URLSearchParams()
    bridgeBody.append("From", callerId)
    bridgeBody.append("To", destination)
    bridgeBody.append("CallerId", callerId)

    const bridgeResponse = await fetch(bridgeEndpoint, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${apiKey}:${apiToken}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: bridgeBody,
    })

    if (!bridgeResponse.ok) {
      await recordAudit(admin, user.id, orgId, null, "broker_call_provider_failed", { broker_id: bId })
      return safeJson({ ok: false, reason: "provider_failed" }, 502)
    }

    // 6. Log Activity
    await admin.from('broker_activity_logs').insert({
      organization_id: orgId,
      broker_id: bId,
      project_id: validUuid(project_id),
      actor_id: user.id,
      activity_type: 'call_attempt',
      outcome: 'connecting',
      notes_safe: 'System initiated secure call bridge.'
    })

    await recordAudit(admin, user.id, orgId, null, "broker_secure_call_requested", { broker_id: bId })

    return safeJson({ ok: true, status: "queued" }, 200)

  } catch (err) {
    return safeJson({ ok: false, reason: "internal_error" }, 500)
  } finally {
    // Immediate variable wipe
    destination = null
    if (bridgeBody) bridgeBody.set("To", "")
    bridgeBody = null
  }
})
