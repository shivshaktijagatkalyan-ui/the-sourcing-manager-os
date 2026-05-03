import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { crypto } from 'https://deno.land/std@0.168.0/crypto/mod.ts'

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

    const formData = await req.formData()
    const file = formData.get('photo') as File
    const site_visit_id = formData.get('site_visit_id') as string

    if (!file || !site_visit_id) throw new Error('Missing file or site_visit_id')

    // 1. Validate Visit State (Service Role)
    const { data: visit, error: fetchError } = await serviceRoleSupabase
      .from('site_visits')
      .select('id, lead_id, status, gps_status')
      .eq('id', site_visit_id)
      .eq('sourcing_manager_id', user.id)
      .single()

    if (fetchError || !visit || visit.status !== 'gps_verified') {
        throw new Error('Invalid visit state for photo upload')
    }

    // 2. Calculate SHA-256 for Evidence Chain
    const arrayBuffer = await file.arrayBuffer()
    const hashBuffer = await crypto.subtle.digest('SHA-256', arrayBuffer)
    const hashArray = Array.from(new Uint8Array(hashBuffer))
    const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('')

    // 3. Upload to Storage (Service Role)
    const filePath = `evidence/${visit.lead_id}/${site_visit_id}/${hashHex}.jpg`
    const { error: uploadError } = await serviceRoleSupabase.storage
      .from('site-evidence')
      .upload(filePath, file, { 
          contentType: 'image/jpeg',
          upsert: false // Non-overwrite policy
      })

    if (uploadError) throw uploadError

    // 4. Atomic Secure Update (Sprint 3 v2)
    const { data: result, error: updateError } = await serviceRoleSupabase.rpc('upload_site_photo_v2', {
        p_visit_id: site_visit_id,
        p_actor_id: user.id,
        p_photo_sha256: hashHex
    })

    if (updateError || !result || !result.ok) throw new Error('Record update failed')

    return new Response(JSON.stringify({ ok: true, hash: hashHex }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ ok: false, reason: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
