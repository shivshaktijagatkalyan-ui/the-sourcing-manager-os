import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const formData = await req.formData()
    const callSid = formData.get('CallSid')
    const status = formData.get('Status')
    const duration = formData.get('Duration')

    if (!callSid) throw new Error('Missing CallSid')

    // Update call_attempts with sanitized data
    const { error } = await supabaseClient
        .from('call_attempts')
        .update({
            call_status: status,
            duration_seconds: duration ? parseInt(duration as string) : null,
            updated_at: new Date().toISOString()
        })
        .eq('provider_call_id', callSid)

    if (error) throw error

    // log_audit_event (system level)
    await supabaseClient.from('audit_events').insert({
        event_type: 'call_callback_received',
        event_context: { call_sid: callSid, status }
    })

    return new Response(JSON.stringify({ ok: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (error) {
    console.error('Callback error:', error.message)
    return new Response(JSON.stringify({ ok: false, reason: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
