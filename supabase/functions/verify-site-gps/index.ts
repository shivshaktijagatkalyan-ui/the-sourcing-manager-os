import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    const serviceRoleSupabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) throw new Error('Unauthorized')

    // Sprint 3: Pilot Active Check
    const { data: isActive, error: activeError } = await serviceRoleSupabase.rpc('is_pilot_active', { p_user_id: user.id })
    if (activeError || !isActive) {
        return new Response(JSON.stringify({ ok: false, reason: 'pilot_user_inactive_or_unconfigured' }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 403,
        })
    }

    const { site_visit_id, latitude, longitude, accuracy_meters } = await req.json()

    // 1. Fetch project coordinates (Service Role)
    const { data: visitData, error: fetchError } = await serviceRoleSupabase
      .from('site_visits')
      .select('projects(latitude, longitude, geofence_radius_meters)')
      .eq('id', site_visit_id)
      .single()

    if (fetchError || !visitData || !visitData.projects) {
      return new Response(JSON.stringify({ ok: false, reason: 'site_visit_not_found' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 404,
      })
    }

    // 2. Calculate distance via RPC (Service Role)
    const { data: distance, error: distError } = await serviceRoleSupabase.rpc('haversine_distance', {
      lat1: latitude,
      lon1: longitude,
      lat2: visitData.projects.latitude,
      lon2: visitData.projects.longitude
    })

    if (distError) {
      return new Response(JSON.stringify({ ok: false, reason: 'calculation_failed' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      })
    }

    // 3. Verify Constraints
    const isInside = distance <= visitData.projects.geofence_radius_meters && accuracy_meters <= 100

    // 4. Atomic Secure Update (Sprint 3 v2)
    const { data: result, error: updateError } = await serviceRoleSupabase.rpc('verify_site_gps_v2', {
        p_visit_id: site_visit_id,
        p_actor_id: user.id,
        p_is_inside: isInside,
        p_lat: latitude,
        p_lng: longitude,
        p_accuracy: accuracy_meters,
        p_distance: distance
    })

    if (updateError || !result || !result.ok) {
      return new Response(JSON.stringify({ ok: false, reason: 'update_failed', error: updateError }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      })
    }

    return new Response(JSON.stringify({ 
      ok: isInside, 
      status: isInside ? 'verified' : 'rejected',
      distance_meters: Math.round(distance)
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ ok: false, reason: 'internal_error' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
