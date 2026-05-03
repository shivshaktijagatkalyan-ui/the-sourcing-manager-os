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

    const { site_visit_id, action, reason } = await req.json()

    if (!['approve', 'reject'].includes(action)) {
      throw new Error('Invalid action')
    }

    // 1. Fetch Visit (Service Role)
    const { data: visit, error: fetchError } = await serviceRoleSupabase
      .from('site_visits')
      .select('id, broker_id, status')
      .eq('id', site_visit_id)
      .eq('broker_id', user.id)
      .single()

    if (fetchError || !visit || visit.status !== 'photo_verified') {
        throw new Error('Invalid visit state for review')
    }

    // 2. Atomic Secure Update (Sprint 3 v2)
    const { data: result, error: updateError } = await serviceRoleSupabase.rpc('broker_review_site_visit_v2', {
        p_visit_id: site_visit_id,
        p_actor_id: user.id,
        p_action: action,
        p_reason: reason
    })

    if (updateError || !result || !result.ok) throw new Error('Review submission failed')

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ ok: false, reason: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
