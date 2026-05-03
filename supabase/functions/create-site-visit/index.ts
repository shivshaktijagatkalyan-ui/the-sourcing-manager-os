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

    const { lead_id, project_id, sourcing_manager_id, scheduled_at } = await req.json()

    // 1. Fetch lead to get broker_id and validate ownership
    const { data: lead, error: leadError } = await serviceRoleSupabase
      .from('leads_public')
      .select('broker_id')
      .eq('id', lead_id)
      .single()

    if (leadError || !lead) {
      return new Response(JSON.stringify({ ok: false, reason: 'lead_not_found' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 404,
      })
    }

    // 2. Validate active data loan
    const { data: hasLoan, error: loanError } = await serviceRoleSupabase.rpc('has_active_data_loan', {
      p_lead_id: lead_id,
      p_user_id: user.id,
      p_purpose: 'site_visit'
    });

    if (loanError || !hasLoan) {
      return new Response(JSON.stringify({ ok: false, reason: 'active_loan_required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      })
    }

    // 3. Create the site visit record (Service Role)
    const { data: visit, error: visitError } = await serviceRoleSupabase
      .from('site_visits')
      .insert({
        lead_id,
        broker_id: lead.broker_id,
        sourcing_manager_id: user.id,
        project_id,
        status: 'scheduled',
        scheduled_at: scheduled_at || new Date().toISOString()
      })
      .select()
      .single()

    if (visitError) {
      return new Response(JSON.stringify({ ok: false, reason: 'visit_creation_failed' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      })
    }

    // 4. Audit the creation (Service Role)
    await serviceRoleSupabase.from('audit_events').insert({
      actor_id: user.id,
      event_type: 'site_visit_created',
      lead_id: lead_id,
      event_context: { site_visit_id: visit.id, project_id }
    })

    return new Response(JSON.stringify({ ok: true, visit_id: visit.id }), {
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
