import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, safeJson } from '../_shared/sprint7.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })

  try {
    const admin = adminClient()

    // 1. Get latest system status
    const { data: statusEvent } = await admin
      .from('system_health_events')
      .select('status, severity, event_type')
      .order('created_at', { ascending: false })
      .limit(1)
      .single()

    // 2. Check for recent critical failures (last 1 hour)
    const oneHourAgo = new Date(Date.now() - 3600000).toISOString()
    const { count: failCount } = await admin
      .from('edge_function_failures')
      .select('id', { count: 'exact', head: true })
      .gte('created_at', oneHourAgo)
      .eq('severity', 'critical')

    const systemStatus = (failCount && failCount > 0) ? 'incident' : (statusEvent?.status ?? 'healthy')

    return safeJson({
      status: systemStatus,
      last_event: statusEvent?.event_type ?? 'none',
      critical_failures_1h: failCount ?? 0,
      timestamp: new Date().toISOString()
    })

  } catch (err) {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
