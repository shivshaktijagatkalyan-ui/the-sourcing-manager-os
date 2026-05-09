import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  corsHeaders,
  currentUser,
  recordAudit,
  requirePermission,
  safeJson,
  validUuid,
} from "../_shared/sprint7.ts"

async function actorContext(admin: ReturnType<typeof adminClient>, userId: string) {
  const { data } = await admin
    .from("pilot_users")
    .select("org_id, status, organizations(status)")
    .eq("user_id", userId)
    .maybeSingle()

  if (!data || data.status !== "active" || data.organizations?.status !== "active") return null
  return { organization_id: data.org_id as string }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders })
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: "unauthorized" }, 401)

    const admin = adminClient()
    const context = await actorContext(admin, user.id)
    if (!context) return safeJson({ ok: false, reason: "access_blocked" }, 403)

    const body = await req.json().catch(() => ({}))
    const siteVisitId = validUuid(body.site_visit_id)
    if (!siteVisitId) return safeJson({ ok: false, reason: "invalid_input" }, 400)

    const { data: visit } = await admin
      .from("site_visits")
      .select("id, organization_id, source_broker_id, source_lead_id, project_id, sourcing_manager_id, status")
      .eq("id", siteVisitId)
      .eq("organization_id", context.organization_id)
      .maybeSingle()

    if (!visit) return safeJson({ ok: false, reason: "visit_not_found" }, 404)

    const canVerify = await requirePermission(admin, user.id, "can_verify_site_visits", context.organization_id)
    if (visit.sourcing_manager_id !== user.id && !canVerify) {
      return safeJson({ ok: false, reason: "not_allowed" }, 403)
    }

    await admin
      .from("site_visits")
      .update({
        status: "client_reached_site",
        client_reached_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq("id", siteVisitId)
      .eq("organization_id", context.organization_id)

    await admin.from("site_visit_confirmations").insert({
      organization_id: context.organization_id,
      site_visit_id: siteVisitId,
      source_broker_id: visit.source_broker_id,
      source_lead_id: visit.source_lead_id,
      project_id: visit.project_id,
      sourcing_manager_id: user.id,
      proof_type: "arrival",
      status: "client_reached_site",
      verified_by: user.id,
    })

    await recordAudit(admin, user.id, context.organization_id, null, "client_reached_site", {
      site_visit_id: siteVisitId,
      lead_id: visit.source_lead_id,
      project_id: visit.project_id,
      source_broker_id: visit.source_broker_id,
      status: "client_reached_site",
      organization_id: context.organization_id,
    })

    return safeJson({ ok: true, status: "client_reached_site" })
  } catch (_) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
