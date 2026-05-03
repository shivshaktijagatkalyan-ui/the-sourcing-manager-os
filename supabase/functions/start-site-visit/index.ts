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

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) throw new Error('Unauthorized')

    const { site_visit_id } = await req.json()

    // 1. Fetch and validate visit
    const { data: visit, error: fetchError } = await supabase
      .from('site_visits')
      .select('*')
      .eq('id', site_visit_id)
      .single()

    if (fetchError || !visit) throw new Error('Site visit not found')
    if (visit.sourcing_manager_id !== user.id) throw new Error('Unauthorized: You are not assigned to this visit')
    if (visit.status !== 'scheduled') throw new Error('Cannot start a visit that is not scheduled')

    // 2. Update status to started
    const { error: updateError } = await supabase
      .from('site_visits')
      .update({ 
        status: 'started',
        updated_at: new Date().toISOString()
      })
      .eq('id', site_visit_id)

    if (updateError) throw updateError

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ ok: false, error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
