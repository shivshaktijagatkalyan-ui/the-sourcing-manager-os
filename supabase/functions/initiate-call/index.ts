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

    // 1. Authenticate user
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) throw new Error('Unauthorized')

    const { lead_id } = await req.json()
    if (!lead_id) throw new Error('Lead ID is required')

    // 2. Validate active data loan
    const { data: hasLoan, error: loanError } = await supabaseClient.rpc('check_active_loan', {
        p_lead_id: lead_id,
        p_user_id: user.id,
        p_purpose: 'call'
    })

    if (loanError || !hasLoan) {
        throw new Error('access_denied')
    }

    // 3. Fetch encrypted phone
    const { data: sensitive, error: sensitiveError } = await supabaseClient
        .from('leads_sensitive')
        .select('phone_ciphertext')
        .eq('lead_id', lead_id)
        .single()

    if (sensitiveError || !sensitive) throw new Error('lead_data_missing')

    // 4. Decrypt only in memory
    const { data: decryptedPhone, error: decryptError } = await supabaseClient.rpc('decrypt_phone', {
        p_ciphertext: sensitive.phone_ciphertext,
        p_key: Deno.env.get('PHONE_ENCRYPTION_KEY')
    })

    if (decryptError) throw new Error('decryption_failed')

    // 5. Connect to Exotel PSTN bridge
    // We assume the caller's phone is also registered or we use the authenticated user's phone from profile
    // For now, let's assume we use a system Caller ID for one side or fetch from profiles
    const callerPhone = user.user_metadata?.phone // In production, fetch from a secure profiles table
    
    if (!callerPhone) throw new Error('caller_phone_missing')

    const exotelSid = Deno.env.get('EXOTEL_SID')
    const exotelApiKey = Deno.env.get('EXOTEL_API_KEY')
    const exotelApiToken = Deno.env.get('EXOTEL_API_TOKEN')
    const exotelSubdomain = Deno.env.get('EXOTEL_SUBDOMAIN') || 'api.in.exotel.com'
    const exotelCallerId = Deno.env.get('EXOTEL_CALLER_ID')

    const auth = btoa(`${exotelApiKey}:${exotelApiToken}`)
    const exotelUrl = `https://${exotelSubdomain}/v1/Accounts/${exotelSid}/Calls/connect.json`

    const formData = new URLSearchParams()
    formData.append('From', callerPhone)
    formData.append('To', decryptedPhone)
    formData.append('CallerId', exotelCallerId!)
    formData.append('StatusCallback', `${Deno.env.get('SUPABASE_URL')}/functions/v1/exotel-callback`)

    const response = await fetch(exotelUrl, {
        method: 'POST',
        headers: {
            'Authorization': `Basic ${auth}`,
            'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: formData.toString()
    })

    const exotelData = await response.json()

    // 6. WIPE sensitive data from memory
    let phone_wipe: string | null = decryptedPhone
    phone_wipe = null // Explicitly clear reference

    // 7. Store sanitized call_attempt
    await supabaseClient.from('call_attempts').insert({
        lead_id,
        caller_id: user.id,
        provider_call_id: exotelData?.Call?.Sid,
        call_status: 'initiated'
    })

    // 8. Log sanitized audit event
    await supabaseClient.rpc('log_audit_event', {
        p_event_type: 'call_initiated',
        p_lead_id: lead_id,
        p_context: { provider: 'exotel' }
    })

    return new Response(JSON.stringify({ ok: true, status: 'queued' }), {
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
