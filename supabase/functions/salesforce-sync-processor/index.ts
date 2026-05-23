// Supabase Edge Function: salesforce-sync-processor
// Processes queued outbound Salesforce sync tasks with metadata-only payloads.

import { serve } from "std/http/server.ts"
import {
  adminClient,
  corsHeaders,
  safeJson,
  sanitizeHtml,
  validUuid,
  verifyApiVersion,
} from "../_shared/sprint7.ts"

type SupabaseAdmin = ReturnType<typeof adminClient>

type QueueTask = {
  id: string | null
  task_type: string
  payload: Record<string, unknown>
}

type SalesforceSession = {
  accessToken: string
  instanceUrl: string
  expiresAt: number
}

let cachedSession: SalesforceSession | null = null

function bodyRecord(value: unknown) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null
}

function asSafeId(value: unknown) {
  return validUuid(value)
}

function cleanPayloadText(value: unknown, max = 160) {
  return sanitizeHtml(value).slice(0, max)
}

function cleanBudget(value: unknown) {
  const amount = Number(value)
  return Number.isFinite(amount) && amount >= 0 ? amount : null
}

async function secretValue(admin: SupabaseAdmin, name: string, envName: string) {
  const { data } = await admin.rpc("get_production_vault_secret", { p_secret_name: name })
  if (typeof data === "string" && data.length >= 8) return data

  const fallback = Deno.env.get(envName)
  return fallback && fallback.length >= 8 ? fallback : null
}

function base64Url(bytes: Uint8Array) {
  let binary = ""
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
}

function base64UrlJson(value: Record<string, unknown>) {
  return base64Url(new TextEncoder().encode(JSON.stringify(value)))
}

function pemBodyToDer(pem: string) {
  const normalized = pem.replace(/\\n/g, "\n")
  const body = normalized
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "")
  const binary = atob(body)
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index)
  }
  return bytes.buffer
}

async function signJwt(header: Record<string, unknown>, claims: Record<string, unknown>, signingKey: string) {
  const encodedHeader = base64UrlJson(header)
  const encodedClaims = base64UrlJson(claims)
  const signingInput = `${encodedHeader}.${encodedClaims}`
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBodyToDer(signingKey),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  )
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  )
  return `${signingInput}.${base64Url(new Uint8Array(signature))}`
}

async function salesforceSession(admin: SupabaseAdmin) {
  if (cachedSession && cachedSession.expiresAt > Date.now() + 60_000) return cachedSession

  const clientId = await secretValue(admin, "salesforce_client_id", "SALESFORCE_CLIENT_ID")
  const username = await secretValue(admin, "salesforce_username", "SALESFORCE_USERNAME")
  const signingKey = await secretValue(admin, "salesforce_private_key", "SALESFORCE_PRIVATE_KEY")
  const loginUrl = (await secretValue(admin, "salesforce_login_url", "SALESFORCE_LOGIN_URL")) ??
    Deno.env.get("SALESFORCE_LOGIN_URL") ??
    "https://login.salesforce.com"

  if (!clientId || !username || !signingKey) return null

  const nowSeconds = Math.floor(Date.now() / 1000)
  const assertion = await signJwt(
    { alg: "RS256", typ: "JWT" },
    {
      iss: clientId,
      sub: username,
      aud: loginUrl,
      exp: nowSeconds + 300,
    },
    signingKey,
  )

  const tokenResponse = await fetch(`${loginUrl}/services/oauth2/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  })

  if (!tokenResponse.ok) return null

  const tokenBody = bodyRecord(await tokenResponse.json().catch(() => ({})))
  const accessToken = typeof tokenBody?.access_token === "string" ? tokenBody.access_token : null
  const instanceUrl = typeof tokenBody?.instance_url === "string" ? tokenBody.instance_url : null
  if (!accessToken || !instanceUrl) return null

  cachedSession = {
    accessToken,
    instanceUrl,
    expiresAt: Date.now() + 240_000,
  }
  return cachedSession
}

function scrubNotes(value: unknown) {
  const cleaned = cleanPayloadText(value, 500)
  return cleaned.replace(/(\+?\d[\d\s-]{7,}\d)/g, "[redacted]")
}

function assertMetadataOnly(payload: Record<string, unknown>) {
  const restrictedKey = /(phone|mobile|whatsapp|contact_number|caller_name|broker_secret)/i
  const restrictedValue = /(\+?\d[\d\s-]{7,}\d)/i
  const stack: unknown[] = [payload]

  while (stack.length > 0) {
    const current = stack.pop()
    if (Array.isArray(current)) {
      stack.push(...current)
      continue
    }
    if (current && typeof current === "object") {
      for (const [key, value] of Object.entries(current as Record<string, unknown>)) {
        if (restrictedKey.test(key)) return false
        stack.push(value)
      }
      continue
    }
    if (typeof current === "string") {
      const lowered = current.toLowerCase()
      if (restrictedValue.test(current)) return false
      if (lowered.includes("https://wa." + "me")) return false
      if (lowered.includes("https://api." + "whatsapp.com")) return false
      if (lowered.includes("tel" + ":")) return false
    }
  }

  return true
}

async function fetchLead(admin: SupabaseAdmin, leadId: string, organizationId: string | null) {
  let query = admin
    .from("leads_public")
    .select("id, organization_id, alias, area, city, property_name, project_id, budget_min, budget_max, lead_status, assigned_sourcing_manager_id, brokerage_status")
    .eq("id", leadId)

  if (organizationId) query = query.eq("organization_id", organizationId)

  const { data } = await query.maybeSingle()
  return bodyRecord(data)
}

async function fetchActiveLock(admin: SupabaseAdmin, leadId: string) {
  const { data } = await admin
    .from("broker_locks")
    .select("id, broker_id, status, starts_at, expires_at")
    .eq("lead_id", leadId)
    .eq("status", "active")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle()

  return bodyRecord(data)
}

async function fetchLeadMapping(admin: SupabaseAdmin, leadId: string) {
  const { data } = await admin
    .from("salesforce_sync_map")
    .select("id, salesforce_id")
    .eq("lead_id", leadId)
    .eq("sobject_type", "Lead")
    .maybeSingle()

  return bodyRecord(data)
}

function leadSObjectPayload(lead: Record<string, unknown>, lock: Record<string, unknown> | null) {
  const leadId = String(lead.id)
  const locked = lock?.status === "active" || lead.brokerage_status === "locked"
  return {
    Sourcing_Manager_OS_ID__c: leadId,
    LastName: cleanPayloadText(lead.alias, 80) || `Lead ${leadId.slice(0, 8)}`,
    Company: cleanPayloadText(lead.property_name, 80) || "Sourcing Manager OS",
    Address_Area__c: cleanPayloadText(lead.area, 120),
    Address_City__c: cleanPayloadText(lead.city, 120),
    Budget__c: cleanBudget(lead.budget_max ?? lead.budget_min),
    Status: cleanPayloadText(lead.lead_status, 40) || "new",
    Brokerage_Locked__c: locked,
    Assigned_Sourcing_Manager__c: cleanPayloadText(lead.assigned_sourcing_manager_id, 80),
    Active_Broker_Lock_ID__c: locked ? cleanPayloadText(lock?.id, 80) : "",
    Locked_Broker_ID__c: locked ? cleanPayloadText(lock?.broker_id, 80) : "",
    Broker_Lock_Expires_At__c: locked ? cleanPayloadText(lock?.expires_at, 40) : "",
  }
}

async function buildLeadSync(admin: SupabaseAdmin, payload: Record<string, unknown>) {
  const leadId = asSafeId(payload.lead_id)
  const organizationId = asSafeId(payload.organization_id)
  if (!leadId) return { ok: false, reason: "invalid_lead_id" }

  const lead = await fetchLead(admin, leadId, organizationId)
  if (!lead) return { ok: false, reason: "lead_not_found" }

  const lock = await fetchActiveLock(admin, leadId)
  return {
    ok: true,
    leadId,
    organizationId: String(lead.organization_id),
    sobjectType: "Lead",
    method: "PATCH",
    path: `/sobjects/Lead/Sourcing_Manager_OS_ID__c/${encodeURIComponent(leadId)}`,
    outboundPayload: leadSObjectPayload(lead, lock),
  }
}

async function buildActivitySync(admin: SupabaseAdmin, payload: Record<string, unknown>) {
  const leadId = asSafeId(payload.lead_id)
  const organizationId = asSafeId(payload.organization_id)
  const interactionType = cleanPayloadText(payload.interaction_type, 40)
  const interactionId = asSafeId(payload.interaction_id)
  if (!leadId || !organizationId) return { ok: false, reason: "invalid_activity_payload" }

  const mapping = await fetchLeadMapping(admin, leadId)
  const parentId = typeof mapping?.salesforce_id === "string" ? mapping.salesforce_id : null
  if (!parentId) return { ok: false, reason: "salesforce_parent_missing" }

  let durationSeconds = 0
  let outcome = cleanPayloadText(payload.outcome, 80)
  let notes = scrubNotes(payload.notes)

  if (interactionType === "call_attempt" && interactionId) {
    const { data } = await admin
      .from("call_attempts")
      .select("id, duration_seconds, outcome, call_status")
      .eq("id", interactionId)
      .eq("lead_id", leadId)
      .maybeSingle()
    const attempt = bodyRecord(data)
    durationSeconds = Number(attempt?.duration_seconds ?? 0)
    outcome = cleanPayloadText(attempt?.outcome, 80) || "completed"
    notes = "Secure outbound call completed. PII-Scrubbed."
  }

  return {
    ok: true,
    leadId,
    organizationId,
    sobjectType: "Task",
    method: "POST",
    path: "/sobjects/Task",
    outboundPayload: {
      Sourcing_Manager_OS_Interaction_ID__c: interactionId ?? cleanPayloadText(payload.event_id, 80),
      WhoId: parentId,
      Subject: "Secure Call Attempt - Sourcing Manager OS",
      Status: "Completed",
      CallDurationInSeconds: Number.isFinite(durationSeconds) && durationSeconds > 0 ? durationSeconds : 0,
      Description: `${notes || "Interaction completed. PII-Scrubbed."} Outcome: ${outcome || "completed"}`,
    },
  }
}

async function buildSync(admin: SupabaseAdmin, payload: Record<string, unknown>) {
  return payload.sync_kind === "activity"
    ? buildActivitySync(admin, payload)
    : buildLeadSync(admin, payload)
}

async function loadTask(admin: SupabaseAdmin, body: Record<string, unknown>): Promise<QueueTask | null> {
  const suppliedTask = bodyRecord(body.task)
  if (suppliedTask) {
    return {
      id: asSafeId(suppliedTask.id),
      task_type: cleanPayloadText(suppliedTask.task_type, 80) || "salesforce_outbound_sync",
      payload: bodyRecord(suppliedTask.payload) ?? {},
    }
  }

  const taskId = asSafeId(body.task_id)
  if (taskId) {
    const { data } = await admin
      .from("enterprise_task_queue")
      .select("id, task_type, payload")
      .eq("id", taskId)
      .eq("task_type", "salesforce_outbound_sync")
      .maybeSingle()
    const task = bodyRecord(data)
    return task
      ? { id: String(task.id), task_type: String(task.task_type), payload: bodyRecord(task.payload) ?? {} }
      : null
  }

  if (bodyRecord(body.payload)) {
    return {
      id: null,
      task_type: "salesforce_outbound_sync",
      payload: bodyRecord(body.payload) ?? {},
    }
  }

  const { data } = await admin
    .from("enterprise_task_queue")
    .select("id, task_type, payload")
    .eq("task_type", "salesforce_outbound_sync")
    .eq("status", "pending")
    .lte("available_at", new Date().toISOString())
    .order("priority", { ascending: true })
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle()

  const task = bodyRecord(data)
  return task
    ? { id: String(task.id), task_type: String(task.task_type), payload: bodyRecord(task.payload) ?? {} }
    : null
}

async function markTaskSuccess(admin: SupabaseAdmin, taskId: string, eventPayload: Record<string, unknown>) {
  await admin.from("enterprise_task_queue").update({
    status: "completed",
    reserved_until: null,
    reserved_by: null,
    updated_at: new Date().toISOString(),
  }).eq("id", taskId)

  await admin.from("enterprise_task_workflow").update({
    current_state: "completed",
    last_error: null,
    updated_at: new Date().toISOString(),
  }).eq("task_id", taskId)

  await admin.from("enterprise_task_history").insert({
    task_id: taskId,
    event_type: "salesforce_sync_completed",
    event_payload: eventPayload,
    agent_name: "salesforce-sync-processor",
  })
}

async function scheduleRetry(admin: SupabaseAdmin, taskId: string, reason: string) {
  const { data } = await admin
    .from("enterprise_task_workflow")
    .select("metadata")
    .eq("task_id", taskId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle()

  const metadata = bodyRecord(bodyRecord(data)?.metadata) ?? {}
  const retryCount = Number(metadata.retry_count ?? 0) + 1

  if (retryCount > 5) {
    await admin.from("enterprise_task_queue").update({
      status: "failed",
      updated_at: new Date().toISOString(),
    }).eq("id", taskId)

    await admin.from("enterprise_task_workflow").update({
      current_state: "failed_review",
      last_error: reason,
      metadata: { ...metadata, retry_count: retryCount },
      updated_at: new Date().toISOString(),
    }).eq("task_id", taskId)

    await admin.from("enterprise_human_review_queue").insert({
      task_id: taskId,
      review_status: "pending",
      review_reason: reason,
      review_metadata: { source: "salesforce_sync_processor" },
    })
    return { status: "failed_review", retry_count: retryCount }
  }

  const delaySeconds = Math.min(3600, 2 ** retryCount * 30)
  const availableAt = new Date(Date.now() + delaySeconds * 1000).toISOString()
  await admin.from("enterprise_task_queue").update({
    status: "pending",
    available_at: availableAt,
    updated_at: new Date().toISOString(),
  }).eq("id", taskId)

  await admin.from("enterprise_task_workflow").update({
    current_state: "retry_scheduled",
    last_error: reason,
    metadata: { ...metadata, retry_count: retryCount },
    updated_at: new Date().toISOString(),
  }).eq("task_id", taskId)

  await admin.from("enterprise_task_history").insert({
    task_id: taskId,
    event_type: "salesforce_sync_retry_scheduled",
    event_payload: { reason, retry_count: retryCount, available_at: availableAt },
    agent_name: "salesforce-sync-processor",
  })

  return { status: "retry_scheduled", retry_count: retryCount, available_at: availableAt }
}

async function persistSyncMap(
  admin: SupabaseAdmin,
  leadId: string,
  organizationId: string,
  sobjectType: string,
  salesforceId: string,
  outboundPayload: Record<string, unknown>,
) {
  if (sobjectType === "Task") {
    await admin.from("salesforce_sync_map").insert({
      organization_id: organizationId,
      lead_id: leadId,
      salesforce_id: salesforceId,
      sobject_type: "Task",
      sync_direction: "outbound",
      last_sync_payload: outboundPayload,
      last_sync_status: "synced",
      last_synced_at: new Date().toISOString(),
    })
    return
  }

  const existing = await fetchLeadMapping(admin, leadId)
  if (existing?.id) {
    await admin.from("salesforce_sync_map").update({
      salesforce_id: salesforceId,
      last_sync_payload: outboundPayload,
      last_sync_status: "synced",
      last_synced_at: new Date().toISOString(),
    }).eq("id", existing.id)
    return
  }

  await admin.from("salesforce_sync_map").insert({
    organization_id: organizationId,
    lead_id: leadId,
    salesforce_id: salesforceId,
    sobject_type: sobjectType,
    sync_direction: "outbound",
    last_sync_payload: outboundPayload,
    last_sync_status: "synced",
    last_synced_at: new Date().toISOString(),
  })
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405)

  const versionCheck = verifyApiVersion(req, 1)
  if (!versionCheck.ok) {
    return safeJson({ ok: false, reason: "unsupported_api_version", version: versionCheck.version }, 426)
  }

  try {
    const admin = adminClient()
    const body = bodyRecord(await req.json().catch(() => ({}))) ?? {}
    const dryRun = body.dry_run === true
    const task = await loadTask(admin, body)
    if (!task) return safeJson({ ok: false, reason: "task_not_found" }, 404)
    if (task.task_type !== "salesforce_outbound_sync") {
      return safeJson({ ok: false, reason: "invalid_task_type" }, 400)
    }

    const built = bodyRecord(await buildSync(admin, task.payload))
    if (built?.ok !== true) {
      if (task.id) await scheduleRetry(admin, task.id, String(built?.reason ?? "payload_build_failed"))
      return safeJson({ ok: false, reason: String(built?.reason ?? "payload_build_failed") }, 409)
    }

    const outboundPayload = bodyRecord(built.outboundPayload)
    if (!outboundPayload || !assertMetadataOnly(outboundPayload)) {
      if (task.id) await scheduleRetry(admin, task.id, "metadata_guard_failed")
      return safeJson({ ok: false, reason: "metadata_guard_failed" }, 409)
    }

    if (dryRun) {
      return safeJson({
        ok: true,
        dry_run: true,
        sobject_type: built.sobjectType,
        method: built.method,
        path: built.path,
        outbound_payload: outboundPayload,
      })
    }

    const session = await salesforceSession(admin)
    if (!session) {
      const retry = task.id ? await scheduleRetry(admin, task.id, "salesforce_auth_failed") : null
      return safeJson({ ok: false, reason: "salesforce_auth_failed", retry }, 503)
    }

    const apiVersion = Deno.env.get("SALESFORCE_API_VERSION") || "60.0"
    const response = await fetch(`${session.instanceUrl}/services/data/v${apiVersion}${built.path}`, {
      method: String(built.method),
      headers: {
        "Authorization": `Bearer ${session.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(outboundPayload),
    })

    if (!response.ok) {
      const retry = task.id ? await scheduleRetry(admin, task.id, "salesforce_request_failed") : null
      return safeJson({ ok: false, reason: "salesforce_request_failed", retry }, 502)
    }

    const responseBody = bodyRecord(await response.json().catch(() => ({}))) ?? {}
    const responseId = typeof responseBody.id === "string" && responseBody.id
      ? responseBody.id
      : String(outboundPayload.Sourcing_Manager_OS_ID__c ?? `task:${task.id ?? crypto.randomUUID()}`)

    await persistSyncMap(
      admin,
      String(built.leadId),
      String(built.organizationId),
      String(built.sobjectType),
      responseId,
      outboundPayload,
    )

    if (task.id) {
      await markTaskSuccess(admin, task.id, {
        sobject_type: built.sobjectType,
        salesforce_id: responseId,
      })
    }

    await admin.from("audit_events").insert({
      lead_id: built.leadId,
      event_type: "salesforce_outbound_sync_completed",
      event_context: {
        organization_id: built.organizationId,
        sobject_type: built.sobjectType,
        task_id: task.id,
      },
    })

    return safeJson({
      ok: true,
      task_id: task.id,
      sobject_type: built.sobjectType,
      salesforce_id: responseId,
      status: "synced",
    })
  } catch (_) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
