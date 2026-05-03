import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const serviceRoleSupabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { entity_id, entity_type } = await req.json()

    if (!entity_id || !entity_type) throw new Error('Missing params')

    // 1. Fetch Audit Events
    const { data: events, error: eventError } = await serviceRoleSupabase
      .from('audit_events')
      .select('event_type, event_context')
      .eq('actor_id', entity_id)

    if (eventError) throw eventError

    // 2. Simple Linear Scoring Model
    let score = 3.0; // Start at neutral
    let components = {
        positive_events: 0,
        negative_events: 0,
        total_events: events.length
    }

    events.forEach(event => {
        if (event.event_type === 'site_visit_state_change') {
            const ns = event.event_context.new_status
            if (ns === 'completed' || ns === 'gps_verified' || ns === 'photo_verified') {
                score += 0.05
                components.positive_events++
            } else if (ns === 'invalid') {
                score -= 0.5
                components.negative_events++
            }
        }
        if (event.event_type === 'gps_verified') {
             score += 0.05
             components.positive_events++
        }
        if (event.event_type === 'gps_rejected') {
             score -= 0.2
             components.negative_events++
        }
    })

    // Clamp score
    score = Math.max(0, Math.min(5, score))

    // 3. Upsert Trust Score
    const { error: updateError } = await serviceRoleSupabase
      .from('trust_scores')
      .upsert({
          entity_id,
          entity_type,
          score: parseFloat(score.toFixed(2)),
          components_json: components,
          last_updated_at: new Date().toISOString()
      }, { onConflict: 'entity_id, entity_type' })

    if (updateError) throw updateError

    return new Response(JSON.stringify({ ok: true, score: score.toFixed(2) }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ ok: false, reason: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
