import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { adminClient, currentUser, requirePermission, safeJson, recordAudit } from '../_shared/sprint7.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } })

  try {
    const user = await currentUser(req)
    if (!user) {
      return safeJson({ ok: false, reason: 'unauthorized' }, 401)
    }

    const admin = adminClient()

    const { lead_id, organization_id } = await req.json()

    if (!lead_id || !organization_id) {
      return safeJson({ ok: false, reason: 'bad_request' }, 400)
    }

    // 1. Permission Gate: Requires can_manage_org_users or platform_admin
    const hasPermission = await requirePermission(admin, user.id, 'can_manage_org_users', organization_id)
    if (!hasPermission) {
      return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)
    }

    // 2. Validate Lead Ownership
    // We must ensure the lead belongs to the target organization before reassigning it.
    const { data: lead, error: leadError } = await admin
      .from('leads_public')
      .select('broker_id')
      .eq('id', lead_id)
      .single()

    if (leadError || !lead) {
      return safeJson({ ok: false, reason: 'lead_not_found' }, 404)
    }

    const { data: currentBrokerOrg, error: currentBrokerOrgError } = await admin
      .from('pilot_users')
      .select('org_id')
      .eq('user_id', lead.broker_id)
      .eq('org_id', organization_id)
      .eq('status', 'active')
      .maybeSingle()

    if (currentBrokerOrgError || !currentBrokerOrg) {
      return safeJson({ ok: false, reason: 'forbidden_org_mismatch' }, 403)
    }

    // 3. Fetch Routing Configs
    const { data: configs, error: configError } = await admin
      .from('lead_routing_configs')
      .select('*')
      .eq('organization_id', organization_id)
      .order('priority', { ascending: false })

    if (configError || !configs || configs.length === 0) {
      throw new Error('routing_config_missing')
    }

    let assignedBrokerId: string | null = null
    let assignedTier: string | null = null

    // 4. Iterate Tiers to find available brokers
    for (const config of configs) {
      const { data: orgBrokers, error: orgBrokerError } = await admin
        .from('pilot_users')
        .select('user_id')
        .eq('org_id', organization_id)
        .eq('status', 'active')
        .eq('role', 'broker')

      if (orgBrokerError) throw new Error('broker_lookup_failed')

      const orgBrokerIds = (orgBrokers ?? []).map((row) => row.user_id)
      if (orgBrokerIds.length === 0) continue

      const { data: brokers, error: brokerError } = await admin
        .from('trust_scores')
        .select('entity_id')
        .eq('entity_type', 'user')
        .gte('score', config.min_trust_score)
        .in('entity_id', orgBrokerIds)
        .limit(5)

      if (brokerError) throw new Error('broker_lookup_failed')

      if (brokers && brokers.length > 0) {
        const selected = brokers[Math.floor(Math.random() * brokers.length)]
        assignedBrokerId = selected.entity_id
        assignedTier = config.tier_name
        break
      }
    }

    if (!assignedBrokerId) {
        return safeJson({ ok: false, reason: 'no_eligible_brokers_found' }, 404)
    }

    // 5. Perform Assignment
    const { error: updateError } = await admin
      .from('leads_public')
      .update({ 
          broker_id: assignedBrokerId,
          lead_status: 'new' 
      })
      .eq('id', lead_id)

    if (updateError) throw new Error('assignment_failed')

    // 6. Record Audit with Actor ID
    await recordAudit(
      admin,
      user.id,
      organization_id,
      assignedBrokerId,
      'lead_auto_routed',
      { lead_id, broker_id: assignedBrokerId, tier: assignedTier, source: 'manual_trigger' }
    )

    return safeJson({ ok: true, assigned_broker_id: assignedBrokerId, tier: assignedTier })

  } catch {
    return safeJson({ ok: false, reason: 'internal_server_error' }, 500)
  }
})
