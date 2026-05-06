import { serve } from 'std/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, corsHeaders } from '../_shared/sprint7.ts'



serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

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

    const { site_visit_id, latitude, longitude, accuracy_meters } = await req.json()

    // 3. Fetch project coordinates and verify organization scope
    const { data: visitData, error: fetchError } = await admin
      .from('site_visits')
      .select('organization_id, projects(latitude, longitude, geofence_radius_meters)')
      .eq('id', site_visit_id)
      .single()

    if (fetchError || !visitData || !visitData.projects) {
      return safeJson({ ok: false, reason: 'site_visit_not_found' }, 404)
    }

    if (visitData.organization_id !== pilot.org_id) {
      return safeJson({ ok: false, reason: 'forbidden_org_mismatch' }, 403)
    }


    // 4. Calculate distance
    const { data: distance, error: distError } = await admin.rpc('haversine_distance', {
      lat1: latitude,
      lon1: longitude,
      lat2: visitData.projects.latitude,
      lon2: visitData.projects.longitude
    })

    if (distError) throw new Error('distance_calculation_failed')

    // 5. Verify Constraints
    const isInside = distance <= visitData.projects.geofence_radius_meters && accuracy_meters <= 100

    // 6. Atomic Secure Update
    const { data: result, error: updateError } = await admin.rpc('verify_site_gps_v2', {
        p_visit_id: site_visit_id,
        p_actor_id: user.id,
        p_is_inside: isInside,
        p_lat: latitude,
        p_lng: longitude,
        p_accuracy: accuracy_meters,
        p_distance: distance
    })

    if (updateError || !result || !result.ok) {
      return safeJson({ ok: false, reason: 'update_failed' }, 500)
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
