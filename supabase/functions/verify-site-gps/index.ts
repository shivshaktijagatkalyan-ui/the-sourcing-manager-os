import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, corsHeaders, validUuid } from '../_shared/sprint7.ts'



serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return safeJson({ ok: false, reason: 'invalid_method' }, 405)

  try {
    const user = await currentUser(req)
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401)

    const admin = adminClient()

    // 1. Fetch Pilot Context
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status, organizations(status)')
      .eq('user_id', user.id)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    // 2. Strict Permission Check
    const allowed = await requirePermission(admin, user.id, 'can_verify_site_visits', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const { site_visit_id, latitude, longitude, accuracy_meters, offline_sync, offline_captured_at } = await req.json()
    const siteVisitId = validUuid(site_visit_id)
    const lat = Number(latitude)
    const lng = Number(longitude)
    const accuracy = Number(accuracy_meters)
    if (!siteVisitId || ![lat, lng, accuracy].every(Number.isFinite)) {
      return safeJson({ ok: false, reason: 'invalid_input' }, 400)
    }

    // 3. Fetch project coordinates and verify organization scope
    const { data: visitData, error: fetchError } = await admin
      .from('site_visits')
      .select('organization_id, sourcing_manager_id, status, projects(latitude, longitude, geofence_radius_meters)')
      .eq('id', siteVisitId)
      .single()

    if (fetchError || !visitData || !visitData.projects) {
      return safeJson({ ok: false, reason: 'site_visit_not_found' }, 404)
    }

    if (visitData.organization_id !== pilot.org_id) {
      return safeJson({ ok: false, reason: 'forbidden_org_mismatch' }, 403)
    }

    if (visitData.sourcing_manager_id !== user.id) {
      return safeJson({ ok: false, reason: 'forbidden_not_assigned' }, 403)
    }

    if (visitData.status !== 'started') {
      return safeJson({ ok: false, reason: 'invalid_state' }, 409)
    }


    // 4. Calculate distance
    const { data: distance, error: distError } = await admin.rpc('haversine_distance', {
      lat1: lat,
      lon1: lng,
      lat2: visitData.projects.latitude,
      lon2: visitData.projects.longitude
    })

    if (distError) throw new Error('distance_calculation_failed')

    // 5. Verify Constraints
    const isInside = distance <= visitData.projects.geofence_radius_meters && accuracy <= 100

    const rpcName = offline_sync === true ? 'apply_offline_site_visit_sync' : 'verify_site_gps_v2'
    const rpcPayload = offline_sync === true ? {
        p_visit_id: siteVisitId,
        p_actor_id: user.id,
        p_is_inside: isInside,
        p_lat: lat,
        p_lng: lng,
        p_accuracy: accuracy,
        p_distance: distance,
        p_captured_at: typeof offline_captured_at === 'string' ? offline_captured_at : new Date().toISOString(),
        p_synced_at: new Date().toISOString()
    } : {
        p_visit_id: siteVisitId,
        p_actor_id: user.id,
        p_is_inside: isInside,
        p_lat: lat,
        p_lng: lng,
        p_accuracy: accuracy,
        p_distance: distance
    }

    // 6. Atomic Secure Update
    const { data: result, error: updateError } = await admin.rpc(rpcName, rpcPayload)

    if (updateError || !result || !result.ok) {
      return safeJson({ ok: false, reason: result?.reason ?? 'update_failed' }, offline_sync === true ? 202 : 500)
    }

    return safeJson({
      ok: isInside,
      status: isInside ? 'verified' : 'rejected',
      distance_meters: Math.round(distance)
    })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
