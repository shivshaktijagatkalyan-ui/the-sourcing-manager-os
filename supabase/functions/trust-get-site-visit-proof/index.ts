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

async function canReadVisit(admin: Admin, userId: string, orgId: string, visit: Record<string, unknown>) {
  if (visit.sourcing_manager_id === userId || visit.broker_id === userId) return true
  const canManage = await requirePermission(admin, userId, "can_manage_broker_crm", orgId)
  const canVerify = await requirePermission(admin, userId, "can_verify_site_visits", orgId)
  if (canManage || canVerify) return true

  const sourceBrokerId = validUuid(visit.source_broker_id)
  if (!sourceBrokerId) return false
  const { data: linked } = await admin.rpc("is_linked_broker_user", {
    p_broker_id: sourceBrokerId,
    p_user_id: userId,
  })
  return linked === true
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
    const siteVisitId = validUuid(body.site_visit_id)
    if (!siteVisitId) return safeJson({ ok: false, reason: "invalid_input" }, 400)

    const { data: visit } = await admin
      .from("site_visits")
      .select("id, organization_id, source_broker_id, broker_id, sourcing_manager_id, status, gps_status, photo_sha256, photo_uploaded_at, gps_verified_at, proof_status, verified_at, visit_done_at, updated_at")
      .eq("id", siteVisitId)
      .eq("organization_id", context.orgId)
      .maybeSingle()

    if (!visit) return safeJson({ ok: false, reason: "not_found_or_forbidden" }, 404)
    if (!(await canReadVisit(admin, user.id, context.orgId, visit))) {
      return safeJson({ ok: false, reason: "not_found_or_forbidden" }, 404)
    }

    const gpsVerified = visit.gps_status === "verified" || ["gps_verified", "qr_verified", "photo_uploaded", "visit_done"].includes(`${visit.status}`)
    const photoUploaded = Boolean(visit.photo_sha256 || visit.photo_uploaded_at || ["photo_uploaded", "visit_done"].includes(`${visit.status}`))
    const timestamp = visit.verified_at ?? visit.visit_done_at ?? visit.photo_uploaded_at ?? visit.gps_verified_at ?? visit.updated_at ?? null

    return safeJson({
      ok: true,
      gps_verified: gpsVerified,
      photo_uploaded: photoUploaded,
      timestamp,
      proof_status: visit.proof_status ?? visit.status ?? "pending",
    })
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
