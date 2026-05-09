import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import {
  adminClient,
  cleanText,
  corsHeaders,
  currentUser,
  recordAudit,
  requirePermission,
  safeJson,
  sha256,
  validUuid,
} from "../_shared/sprint7.ts"

const proofTypes = new Set(["gps", "qr", "visit_code", "photo", "visit_done", "no_show"])

async function actorContext(admin: ReturnType<typeof adminClient>, userId: string) {
  const { data } = await admin
    .from("pilot_users")
    .select("org_id, status, organizations(status)")
    .eq("user_id", userId)
    .maybeSingle()

  if (!data || data.status !== "active" || data.organizations?.status !== "active") return null
  return { organization_id: data.org_id as string }
}

function projectRow(value: unknown) {
  if (Array.isArray(value)) return value[0] ?? null
  return value && typeof value === "object" ? value as Record<string, unknown> : null
}

function meters(lat1: number, lng1: number, lat2: number, lng2: number) {
  const radius = 6371000
  const toRad = (value: number) => value * Math.PI / 180
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2
  return radius * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

async function storeConfirmation(
  admin: ReturnType<typeof adminClient>,
  visit: Record<string, unknown>,
  actorId: string,
  proofType: string,
  status: string,
  extra: Record<string, unknown> = {},
) {
  await admin.from("site_visit_confirmations").insert({
    organization_id: visit.organization_id,
    site_visit_id: visit.id,
    source_broker_id: visit.source_broker_id,
    source_lead_id: visit.source_lead_id,
    project_id: visit.project_id,
    sourcing_manager_id: actorId,
    proof_type: proofType,
    status,
    verified_by: actorId,
    ...extra,
  })
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
    const proofType = typeof body.proof_type === "string" ? body.proof_type : ""
    if (!siteVisitId || !proofTypes.has(proofType)) {
      return safeJson({ ok: false, reason: "invalid_input" }, 400)
    }

    const { data: visit } = await admin
      .from("site_visits")
      .select("id, organization_id, lead_id, source_lead_id, source_broker_id, broker_id, project_id, sourcing_manager_id, status, visit_code_hash, qr_code_hash, projects(latitude, longitude, geofence_radius_meters)")
      .eq("id", siteVisitId)
      .eq("organization_id", context.organization_id)
      .maybeSingle()

    if (!visit) return safeJson({ ok: false, reason: "visit_not_found" }, 404)

    const canVerify = await requirePermission(admin, user.id, "can_verify_site_visits", context.organization_id)
    if (visit.sourcing_manager_id !== user.id && !canVerify) {
      return safeJson({ ok: false, reason: "not_allowed" }, 403)
    }

    const now = new Date().toISOString()

    if (proofType === "no_show") {
      await admin
        .from("site_visits")
        .update({ status: "no_show", no_show_at: now, updated_at: now })
        .eq("id", siteVisitId)
        .eq("organization_id", context.organization_id)

      await storeConfirmation(admin, visit, user.id, "no_show", "no_show")
      await recordAudit(admin, user.id, context.organization_id, null, "site_visit_no_show", {
        site_visit_id: siteVisitId,
        lead_id: visit.source_lead_id,
        project_id: visit.project_id,
        source_broker_id: visit.source_broker_id,
        status: "no_show",
        organization_id: context.organization_id,
      })

      return safeJson({ ok: true, status: "no_show" })
    }

    if (proofType === "gps") {
      const project = projectRow(visit.projects)
      const lat = Number(body.latitude)
      const lng = Number(body.longitude)
      const accuracy = Number(body.accuracy_meters ?? body.gps_accuracy_meters ?? 999)
      const projectLat = Number(project?.latitude)
      const projectLng = Number(project?.longitude)
      const radius = Number(project?.geofence_radius_meters ?? 150)

      if (![lat, lng, projectLat, projectLng, accuracy].every(Number.isFinite)) {
        return safeJson({ ok: false, reason: "gps_input_invalid" }, 400)
      }

      const distance = meters(lat, lng, projectLat, projectLng)
      if (distance > radius || accuracy > 100) {
        return safeJson({ ok: false, status: "rejected" }, 409)
      }

      await admin
        .from("site_visits")
        .update({
          status: "gps_verified",
          gps_status: "verified",
          submitted_lat: lat,
          submitted_lng: lng,
          gps_accuracy_meters: accuracy,
          distance_from_project_meters: Math.round(distance),
          gps_verified_at: now,
          proof_status: "partial",
          updated_at: now,
        })
        .eq("id", siteVisitId)
        .eq("organization_id", context.organization_id)

      await storeConfirmation(admin, visit, user.id, "gps", "gps_verified", {
        submitted_lat: lat,
        submitted_lng: lng,
        gps_accuracy_meters: accuracy,
        distance_from_project_meters: Math.round(distance),
      })

      await recordAudit(admin, user.id, context.organization_id, null, "gps_verified", {
        site_visit_id: siteVisitId,
        lead_id: visit.source_lead_id,
        project_id: visit.project_id,
        source_broker_id: visit.source_broker_id,
        status: "gps_verified",
        organization_id: context.organization_id,
      })

      return safeJson({ ok: true, status: "gps_verified" })
    }

    if (proofType === "qr" || proofType === "visit_code") {
      const proofValue = cleanText(body.proof_value, 160)
      if (!proofValue) return safeJson({ ok: false, reason: "proof_required" }, 400)

      const proofHash = await sha256(proofValue)
      const expected = proofType === "qr" ? visit.qr_code_hash : visit.visit_code_hash
      if (expected && expected !== proofHash) {
        return safeJson({ ok: false, status: "rejected" }, 409)
      }

      const updatePayload = proofType === "qr"
        ? { status: "qr_verified", qr_verified_at: now, proof_status: "partial", updated_at: now }
        : { status: "qr_verified", visit_code_verified_at: now, proof_status: "partial", updated_at: now }

      await admin
        .from("site_visits")
        .update(updatePayload)
        .eq("id", siteVisitId)
        .eq("organization_id", context.organization_id)

      await storeConfirmation(admin, visit, user.id, proofType, "qr_verified", { proof_ref_hash: proofHash })
      await recordAudit(admin, user.id, context.organization_id, null, "qr_verified", {
        site_visit_id: siteVisitId,
        lead_id: visit.source_lead_id,
        project_id: visit.project_id,
        source_broker_id: visit.source_broker_id,
        status: "qr_verified",
        organization_id: context.organization_id,
      })

      return safeJson({ ok: true, status: "qr_verified" })
    }

    if (proofType === "photo") {
      const ref = cleanText(body.proof_ref_hash, 180)
      const path = cleanText(body.photo_storage_path, 240)
      if (!ref && !path) return safeJson({ ok: false, reason: "proof_required" }, 400)

      await admin
        .from("site_visits")
        .update({
          status: "photo_uploaded",
          photo_sha256: ref || null,
          photo_storage_path: path || null,
          photo_uploaded_at: now,
          proof_status: "partial",
          updated_at: now,
        })
        .eq("id", siteVisitId)
        .eq("organization_id", context.organization_id)

      await storeConfirmation(admin, visit, user.id, "photo", "photo_uploaded", {
        proof_ref_hash: ref || null,
        photo_storage_path: path || null,
      })

      return safeJson({ ok: true, status: "photo_uploaded" })
    }

    await admin
      .from("site_visits")
      .update({
        status: "visit_done",
        proof_status: "verified",
        verified_at: now,
        visit_done_at: now,
        updated_at: now,
      })
      .eq("id", siteVisitId)
      .eq("organization_id", context.organization_id)

    await admin
      .from("leads_public")
      .update({
        lead_status: "visit_verified",
        conversion_stage: "visit_verified",
        brokerage_status: "locked",
        updated_at: now,
      })
      .eq("id", visit.source_lead_id ?? visit.lead_id)
      .eq("organization_id", context.organization_id)

    const lockLeadId = visit.source_lead_id ?? visit.lead_id
    const { data: existingLock } = await admin
      .from("broker_locks")
      .select("id")
      .eq("lead_id", lockLeadId)
      .eq("broker_id", visit.broker_id)
      .eq("status", "active")
      .maybeSingle()

    const lockUntil = new Date(Date.now() + 45 * 24 * 60 * 60 * 1000).toISOString()
    if (existingLock?.id) {
      await admin
        .from("broker_locks")
        .update({ source_site_visit_id: siteVisitId, expires_at: lockUntil, updated_at: now })
        .eq("id", existingLock.id)
    } else {
      await admin.from("broker_locks").insert({
        lead_id: lockLeadId,
        broker_id: visit.broker_id,
        source_site_visit_id: siteVisitId,
        status: "active",
        starts_at: now,
        expires_at: lockUntil,
      })
    }

    await storeConfirmation(admin, visit, user.id, "visit_done", "visit_done")
    await recordAudit(admin, user.id, context.organization_id, null, "visit_done", {
      site_visit_id: siteVisitId,
      lead_id: visit.source_lead_id,
      project_id: visit.project_id,
      source_broker_id: visit.source_broker_id,
      status: "visit_done",
      organization_id: context.organization_id,
    })

    return safeJson({ ok: true, status: "visit_done" })
  } catch (_) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500)
  }
})
