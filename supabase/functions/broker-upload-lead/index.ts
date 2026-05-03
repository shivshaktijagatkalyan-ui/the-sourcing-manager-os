import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // Authenticate user
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) throw new Error('Unauthorized')

    const { phone, alias, area, city, property_name, budget_min, budget_max } = await req.json()

    if (!phone || !alias) {
        throw new Error('Phone and Alias are required')
    }

    // This violates the system constitution if we log the phone.
    // console.log(`Uploading lead with phone: ${phone}`) // NEVER DO THIS

    // Encryption logic (Simulated pgcrypto-compatible or standard AES)
    // For this implementation, we will use a dedicated RPC to handle encryption via pgcrypto
    // to keep the key management inside Postgres as requested, OR we encrypt here.
    // The user said: "encryption/decryption RPC functions using pgcrypto"
    
    // Let's use the RPC for encryption to ensure database-level security
    const { data: encryptedData, error: encryptError } = await supabaseClient.rpc('encrypt_phone', {
        p_phone: phone,
        p_key: Deno.env.get('PHONE_ENCRYPTION_KEY')
    })

    if (encryptError) throw encryptError

    // Insert into leads_public
    const { data: lead, error: leadError } = await supabaseClient
        .from('leads_public')
        .insert({
            broker_id: user.id,
            alias,
            area,
            city,
            property_name,
            budget_min,
            budget_max
        })
        .select()
        .single()

    if (leadError) throw leadError

    // Insert into leads_sensitive
    const { error: sensitiveError } = await supabaseClient
        .from('leads_sensitive')
        .insert({
            lead_id: lead.id,
            phone_ciphertext: encryptedData
        })

    if (sensitiveError) throw sensitiveError

    // Log audit event
    await supabaseClient.rpc('log_audit_event', {
        p_event_type: 'lead_upload',
        p_lead_id: lead.id,
        p_context: { alias }
    })

    return new Response(JSON.stringify({ ok: true, lead_id: lead.id, alias: lead.alias }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    return new Response(JSON.stringify({ ok: false, reason: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
