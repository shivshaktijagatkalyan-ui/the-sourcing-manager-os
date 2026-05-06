import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  anonClient,
  cleanText,
  corsHeaders,
  currentUser,
  requirePermission,
  safeJson,
  validUuid,
} from "../_shared/sprint7.ts"

const PHONE_REGEX = /(\+?\d{1,4}[\s-]?)?\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{4}/g

function sanitizeNotes(value: unknown) {
  const cleaned = cleanText(value, 500)
  if (!cleaned) return ""
  if (PHONE_REGEX.test(cleaned)) return "[CLEANED: Contact info removed]"
  return cleaned
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: "unauthorized" }, 401)

    const admin = adminClient()
    const body = await req.json().catch(() => ({}))
    const action = typeof body.action === "string" ? body.action : ""

    if (action === "assign_lead_to_caller") {
      const leadId = validUuid(body.lead_id)
      const callerId = validUuid(body.caller_id)
      const duration = parseInt(body.loan_duration_hours) || 24
      
      if (!leadId || !callerId) return safeJson({ ok: false, reason: "invalid_ids" }, 400)

      const { data: lead, error: leadError } = await admin
        .from("leads_public")
        .select("organization_id")
        .eq("id", leadId)
        .maybeSingle()

      if (leadError || !lead?.organization_id) return safeJson({ ok: false, reason: "lead_not_found" }, 404)

      const allowed = await requirePermission(admin, user.id, "can_grant_data_loans", lead.organization_id)
      if (!allowed) return safeJson({ ok: false, reason: "forbidden_permission_required" }, 403)

      const { data: result, error: assignError } = await admin.rpc("assign_lead_to_caller_v2", {
        p_lead_id: leadId,
        p_caller_id: callerId,
        p_actor_id: user.id,
        p_org_id: lead.organization_id,
        p_loan_duration_hours: duration
      })

      if (assignError || !result?.ok) {
        return safeJson({ ok: false, reason: result?.reason || "assignment_failed" }, 409)
      }

      return safeJson({ ok: true, lead_id: leadId, assigned_caller_id: callerId, data_loan_status: "active" })
    }

    if (action === "update_call_outcome") {
      const leadId = validUuid(body.lead_id)
      const outcome = cleanText(body.outcome, 40)
      if (!leadId || !outcome) return safeJson({ ok: false, reason: "missing_fields" }, 400)

      const { error } = await anonClient(req).rpc("update_lead_call_outcome", {
        p_lead_id: leadId,
        p_outcome: outcome,
        p_notes: sanitizeNotes(body.notes),
        p_next_followup: body.next_followup_at ?? null,
      })

      if (error) return safeJson({ ok: false, reason: "outcome_update_failed" }, 409)

      return safeJson({ ok: true })
    }

    return safeJson({ ok: false, reason: "unimplemented_action" }, 501)
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
