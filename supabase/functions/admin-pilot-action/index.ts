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

    // 1. Verify Admin Role
    const { data: adminRecord, error: adminError } = await serviceRoleSupabase
      .from('pilot_users')
      .select('role, org_id, status')
      .eq('user_id', user.id)
      .single()

    if (adminError || !adminRecord || adminRecord.role !== 'admin' || adminRecord.status !== 'active') {
      return new Response(JSON.stringify({ ok: false, reason: 'forbidden_admin_access' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 403,
      })
    }

    const { action, payload } = await req.json()

    if (action === 'create_organization') {
      const { name } = payload
      const { data, error } = await serviceRoleSupabase
        .from('organizations')
        .insert({ name })
        .select()
        .single()
      
      if (error) throw error
      return new Response(JSON.stringify({ ok: true, organization: data }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (action === 'update_organization_status') {
      const { org_id, status } = payload
      const { data, error } = await serviceRoleSupabase
        .from('organizations')
        .update({ status })
        .eq('id', org_id)
        .select()
        .single()
      
      if (error) throw error
      return new Response(JSON.stringify({ ok: true, organization: data }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (action === 'set_user_role') {
        const { target_user_id, target_org_id, role, status } = payload
        const { data, error } = await serviceRoleSupabase
          .from('pilot_users')
          .upsert({ 
              user_id: target_user_id, 
              org_id: target_org_id, 
              role, 
              status: status ?? 'active' 
          }, { onConflict: 'user_id, org_id' })
          .select()
          .single()
        
        if (error) throw error
        return new Response(JSON.stringify({ ok: true, pilot_user: data }), {
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
