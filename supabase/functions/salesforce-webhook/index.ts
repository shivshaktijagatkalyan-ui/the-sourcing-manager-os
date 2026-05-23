// Supabase Edge Function: salesforce-webhook
// Receives signed Salesforce lead events and routes restricted contact data
// through the encrypted lead vault before queueing downstream sync work.

import { serve } from "std/http/server.ts"
import {
  adminClient,
  corsHeaders,
  hmacSha256,
  safeJson,
  sanitizeHtml,
  sha256,
  timingSafeEqualHex,
  validUuid,
  validatePhone,
  verifyApiVersion,
} from "../_shared/sprint7.ts"
import { createEnterpriseTask } from "../_shared/orchestration/index.ts"

type SupabaseAdmin = ReturnType<typeof adminClient>

function signatureHex(value: string | null) {
  if (!value) return null
  const cleaned = value.trim()
  const prefixed = cleaned.match(/^sha256=([0-9a-f]+)$/i)
  const hex = prefixed ? prefixed[1] : cleaned
  return /^[0-9a-f]+$/i.test(hex) ? hex.toLowerCase() : null
}

async function secretValue(admin: SupabaseAdmin, name: string, envName: string) {
  const { data } = await admin.rpc("get_production_vault_secret", { p_secret_name: name })
  if (typeof data === "string" && data.length >= 16) return data

  const fallback = Deno.env.get(envName)
  return fallback && fallback.length >= 16 ? fallback : null
}

function bodyRecord(value: unknown) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null
}

function cleanAmount(value: unknown) {
  if (value === undefined || value === null || value === "") return null
  const parsed = Number(value)
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null
}

async function auditRejected(admin: SupabaseAdmin, reason: string, signaturePresent: boolean) {
  await admin.from("audit_events").insert({
    event_type: "salesforce_webhook_rejected",
    event_context: {
      reason,
      signature_present: signaturePresent,
    },
  })
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405)

  const versionCheck = verifyApiVersion(req, 1)
  if (!versionCheck.ok) {
    return safeJson({ ok: false, reason: "unsupported_api_version", version: versionCheck.version }, 426)
  }

  let oneTimeContact: string | null = null

  try {
    const admin = adminClient()
    const rawBody = await req.text()
    if (!rawBody.trim()) return safeJson({ ok: false, reason: "empty_payload" }, 400)

    const suppliedSignature = signatureHex(req.headers.get("X-Salesforce-Signature"))
    const webhookSecret = await secretValue(admin, "salesforce_webhook_secret", "SALESFORCE_WEBHOOK_SECRET")
    if (!suppliedSignature || !webhookSecret) {
      await auditRejected(admin, "missing_signature_or_secret", Boolean(suppliedSignature))
      return safeJson({ ok: false, reason: "invalid_signature" }, 401)
    }

    const expectedSignature = await hmacSha256(rawBody, webhookSecret)
    if (!timingSafeEqualHex(suppliedSignature, expectedSignature)) {
      await auditRejected(admin, "signature_mismatch", true)
      return safeJson({ ok: false, reason: "invalid_signature" }, 401)
    }

    const body = bodyRecord(JSON.parse(rawBody))
    const data = bodyRecord(body?.data)
    if (!body || !data) return safeJson({ ok: false, reason: "malformed_payload" }, 400)

    const eventId = sanitizeHtml(body.event_id).slice(0, 160)
    const eventType = sanitizeHtml(body.event_type || "Lead_Captured").slice(0, 80)
    const organizationId = validUuid(body.organization_id) ?? validUuid(data.organization_id)
    const salesforceLeadId = sanitizeHtml(data.salesforce_lead_id).slice(0, 80)
    const alias = sanitizeHtml(data.alias).slice(0, 120)
    const area = sanitizeHtml(data.area).slice(0, 120)
    const city = sanitizeHtml(data.city).slice(0, 120)
    const budget = cleanAmount(data.budget)
    oneTimeContact = validatePhone(data.contact_phone)

    const missingFields = []
    if (!eventId) missingFields.push("event_id")
    if (!organizationId) missingFields.push("organization_id")
    if (!salesforceLeadId) missingFields.push("data.salesforce_lead_id")
    if (!alias) missingFields.push("data.alias")
    if (!oneTimeContact) missingFields.push("data.contact_phone")
    if (missingFields.length > 0) {
      return safeJson({ ok: false, reason: "missing_required_fields", fields: missingFields }, 400)
    }

    const signatureHash = await sha256(suppliedSignature)
    const payloadHash = await sha256(rawBody)
    const idempotencyInsert = await admin
      .from("salesforce_webhook_idempotency")
      .insert({
        event_id: eventId,
        organization_id: organizationId,
        event_type: eventType,
        signature_hash: signatureHash,
        payload_hash: payloadHash,
      })

    if (idempotencyInsert.error) {
      const duplicate = typeof idempotencyInsert.error.message === "string" &&
        /duplicate|violates unique/i.test(idempotencyInsert.error.message)
      if (duplicate) {
        await admin.from("audit_events").insert({
          event_type: "salesforce_webhook_duplicate_skipped",
          event_context: {
            organization_id: organizationId,
            event_id: eventId,
          },
        })
        return safeJson({ ok: true, reason: "duplicate_skipped" }, 200)
      }
      return safeJson({ ok: false, reason: "idempotency_check_failed" }, 500)
    }

    const ingest = await admin.rpc("ingest_salesforce_lead_secure", {
      p_organization_id: organizationId,
      p_salesforce_lead_id: salesforceLeadId,
      p_event_id: eventId,
      p_alias: alias,
      p_area: area || null,
      p_city: city || null,
      p_budget: budget,
      p_restricted_contact: oneTimeContact,
    })
    oneTimeContact = null

    const result = bodyRecord(ingest.data)
    if (ingest.error || result?.ok !== true) {
      return safeJson({ ok: false, reason: String(result?.reason ?? "secure_ingest_failed") }, 409)
    }

    const leadId = validUuid(result.lead_id)
    if (!leadId) return safeJson({ ok: false, reason: "secure_ingest_failed" }, 500)

    const taskResult = await createEnterpriseTask(
      admin,
      "salesforce_inbound_ingest",
      {
        event_id: eventId,
        organization_id: organizationId,
        lead_id: leadId,
        salesforce_id: salesforceLeadId,
      },
      {
        source: "salesforce_webhook",
        event_type: eventType,
        ingest_status: result.status,
      },
      60,
    )

    if (!taskResult.ok && taskResult.reason !== "duplicate_task") {
      return safeJson({ ok: false, reason: "queue_insert_failed" }, 500)
    }

    await admin.from("audit_events").insert({
      lead_id: leadId,
      event_type: "salesforce_webhook_ingested",
      event_context: {
        organization_id: organizationId,
        event_id: eventId,
        task_status: taskResult.reason === "duplicate_task" ? "duplicate_task" : "enqueued",
      },
    })

    return safeJson({
      ok: true,
      event_id: eventId,
      lead_id: leadId,
      status: taskResult.reason === "duplicate_task" ? "duplicate_task" : "enqueued",
    }, result.status === "created" ? 201 : 200)
  } catch (_) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  } finally {
    oneTimeContact = null
  }
})
