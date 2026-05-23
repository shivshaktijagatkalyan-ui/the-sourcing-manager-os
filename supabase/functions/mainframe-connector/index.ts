// Supabase Deno Edge Function: mainframe-connector
// Facilitates secure transactional queries between Sourcing Manager OS and IBM z/OS / CICS Mainframes.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  currentUser,
  safeJson,
  corsHeaders,
  validUuid,
  sanitizeHtml,
  checkRateLimit,
  verifyApiVersion
} from "../_shared/sprint7.ts"

// COBOL Status Key Mapping Table
const COBOL_STATUS_KEYS: Record<string, { reason: string; status: number }> = {
  "00": { reason: "success", status: 200 },
  "10": { reason: "end_of_file", status: 200 },
  "23": { reason: "record_not_found", status: 404 },
  "30": { reason: "boundary_violation", status: 400 },
  "34": { reason: "disk_space_exhausted", status: 507 },
  "91": { reason: "authorization_failed", status: 401 },
  "93": { reason: "resource_locked", status: 423 },
  "99": { reason: "system_check_failed", status: 500 },
}

interface MainframeConfig {
  host: string
  apiKey: string
  racfUser: string
  racfPass: string
  isMock: boolean
}

function mainframeConfig(): MainframeConfig {
  const isMock = Deno.env.get("ENABLE_MAINFRAME_MOCK") !== "false"
  return {
    host: Deno.env.get("MAINFRAME_HOST") || "https://zos-connect.enterprise.internal:9443",
    apiKey: Deno.env.get("MAINFRAME_API_KEY") || "mock-secret-api-key-2026",
    racfUser: Deno.env.get("MAINFRAME_RACF_USER") || "SYSADM",
    racfPass: Deno.env.get("MAINFRAME_RACF_PASSWORD") || "PASS1234",
    isMock
  }
}

// Helper: Converts standard string to EBCDIC IBM-1047 byte array representation (Mock representation)
function asciiToEbcdicMock(str: string): Uint8Array {
  const bytes = new TextEncoder().encode(str)
  // Simplified shift for demonstration in Deno environment
  return bytes.map(b => (b + 0x40) % 256)
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  // 1. Verify API Version
  const apiCheck = verifyApiVersion(req, 1)
  if (!apiCheck.ok) {
    return safeJson({ ok: false, reason: 'api_version_unsupported' }, 400)
  }

  try {
    // 2. Authenticate User
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()

    // 3. Fetch user's active organization pilot context
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status, role, organizations(status)')
      .eq('user_id', user.id)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    // 4. Rate Limiting Check
    const rateLimitOk = await checkRateLimit(user.id, 'mainframe_query', pilot.org_id)
    if (!rateLimitOk.ok) {
      return safeJson({ ok: false, reason: 'rate_limit_exceeded' }, 429)
    }

    const body = await req.json()
    const action = sanitizeHtml(body.action)
    const payload = body.payload || {}

    if (!action) {
      return safeJson({ ok: false, reason: 'action_required' }, 400)
    }

    const config = mainframeConfig()

    // 5. Query execution logic
    if (config.isMock) {
      // Simulate Mainframe response structure
      let cobolStatus = "00"
      let mainframeData: Record<string, any> = {}

      if (action === "query_property_records") {
        const queryId = sanitizeHtml(payload.property_id || "")
        if (!queryId) {
          cobolStatus = "30" // Boundary violation / invalid key
        } else if (queryId === "NOTFOUND") {
          cobolStatus = "23" // Record not found
        } else {
          mainframeData = {
            cics_transaction: "QPROPS01",
            ebcdic_payload_hex: Array.from(asciiToEbcdicMock(queryId)).map(b => b.toString(16).padStart(2, '0')).join(''),
            property_id: queryId,
            developer_block: "BLOCK-A5",
            inventory_status: "AVAILABLE",
            carpet_area_sqft: 1250,
            db2_last_sync_timestamp: new Date().toISOString()
          }
        }
      } else if (action === "validate_broker_identity") {
        const brokerLic = sanitizeHtml(payload.license_number || "")
        if (!brokerLic) {
          cobolStatus = "30"
        } else {
          mainframeData = {
            cics_transaction: "VBRKID02",
            registered_name: "OM SHREE REAL ESTATE PVT LTD",
            verification_status: "CERTIFIED",
            rera_registration_status: "ACTIVE",
            expiry_date: "2030-12-31"
          }
        }
      } else {
        return safeJson({ ok: false, reason: "unimplemented_action" }, 501)
      }

      // Map COBOL status key to standard HTTP response
      const mapping = COBOL_STATUS_KEYS[cobolStatus] || { reason: "internal_mainframe_error", status: 500 }

      if (cobolStatus !== "00" && cobolStatus !== "10") {
        // Log transaction failure in audit events
        await admin.from('audit_events').insert({
          actor_id: user.id,
          event_type: 'mainframe_transaction_failed',
          event_context: {
            action,
            cobol_status: cobolStatus,
            error_reason: mapping.reason,
            organization_id: pilot.org_id
          }
        })

        return safeJson({ ok: false, reason: mapping.reason, cobol_status: cobolStatus }, mapping.status)
      }

      return safeJson({
        ok: true,
        cobol_status: cobolStatus,
        data: mainframeData
      }, 200)

    } else {
      // Direct integration with z/OS Connect EE REST Gateway
      const zOSConnectEndpoint = `${config.host}/api/v1/cics/transactions`

      const response = await fetch(zOSConnectEndpoint, {
        method: "POST",
        headers: {
          "Authorization": `Basic ${btoa(`${config.racfUser}:${config.racfPass}`)}`,
          "X-API-KEY": config.apiKey,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          transaction_id: action === "query_property_records" ? "QPROPS01" : "VBRKID02",
          commarea_length: 256,
          input_fields: payload
        })
      })

      if (!response.ok) {
        throw new Error("mainframe_network_failed")
      }

      const rawResult = await response.json()
      const cobolStatus = rawResult.cobol_status_key || "99"
      const mapping = COBOL_STATUS_KEYS[cobolStatus] || { reason: "internal_mainframe_error", status: 500 }

      if (cobolStatus !== "00" && cobolStatus !== "10") {
        return safeJson({ ok: false, reason: mapping.reason, cobol_status: cobolStatus }, mapping.status)
      }

      return safeJson({
        ok: true,
        cobol_status: cobolStatus,
        data: rawResult.output_fields
      }, 200)
    }

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
