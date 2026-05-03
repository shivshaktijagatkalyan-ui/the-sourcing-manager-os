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

    const { action, payload } = await req.json()

    // 1. Get User Org
    const { data: pilotUser, error: pilotError } = await serviceRoleSupabase
      .from('pilot_users')
      .select('org_id, role, status')
      .eq('user_id', user.id)
      .single()

    if (pilotError || !pilotUser || pilotUser.status !== 'active') {
      return new Response(JSON.stringify({ ok: false, reason: 'inactive_pilot_user' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      })
    }

    if (action === 'open_dispute') {
      const { target_id, target_type, type, comment } = payload
      
      const { data: dispute, error: dError } = await serviceRoleSupabase
        .from('disputes')
        .insert({
            org_id: pilotUser.org_id,
            target_id,
            target_type,
            type,
            status: 'opened'
        })
        .select()
        .single()

      if (dError) throw dError

      // Add initial event
      await serviceRoleSupabase
        .from('dispute_events')
        .insert({
            dispute_id: dispute.id,
            actor_id: user.id,
            event_type: 'dispute_opened',
            comment
        })

      return new Response(JSON.stringify({ ok: true, dispute_id: dispute.id }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (action === 'add_event') {
        const { dispute_id, event_type, comment, evidence_refs } = payload
        
        // Verify org ownership
        const { data: dispute, error: dError } = await serviceRoleSupabase
            .from('disputes')
            .select('org_id')
            .eq('id', dispute_id)
            .single()
        
        if (dError || dispute.org_id !== pilotUser.org_id) {
            throw new Error('Unauthorized dispute access')
        }

        const { data: event, error: eError } = await serviceRoleSupabase
            .from('dispute_events')
            .insert({
                dispute_id,
                actor_id: user.id,
                event_type,
                comment,
                evidence_refs
            })
            .select()
            .single()
        
        if (eError) throw eError
        return new Response(JSON.stringify({ ok: true, event_id: event.id }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }

    if (action === 'resolve_dispute') {
        const { dispute_id, resolution_status, comment } = payload
        
        if (pilotUser.role !== 'admin') {
            throw new Error('Only admins can resolve disputes')
        }

        const { error: uError } = await serviceRoleSupabase
            .from('disputes')
            .update({ status: resolution_status, updated_at: new Date().toISOString() })
            .eq('id', dispute_id)

        if (uError) throw uError

        await serviceRoleSupabase
            .from('dispute_events')
            .insert({
                dispute_id,
                actor_id: user.id,
                event_type: 'dispute_resolved',
                comment
            })

        return new Response(JSON.stringify({ ok: true }), {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        })
    }

    return new Response(JSON.stringify({ ok: false, reason: 'unknown_action' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })

  } catch (error) {
    return new Response(JSON.stringify({ ok: false, reason: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
