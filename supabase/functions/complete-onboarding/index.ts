import { serve } from "std/http/server.ts";
import { adminClient, corsHeaders, currentUser, defaultTemplateForRole, safeJson, legacyRole } from "../_shared/sprint7.ts";

function generateBrokerCode(name: string): string {
  const prefix = (name || 'BK').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 4).padEnd(2, 'X');
  const suffix = Math.floor(1000 + Math.random() * 9000).toString();
  const ts = Date.now().toString().slice(-4);
  return `${prefix}${ts}${suffix}`;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const user = await currentUser(req);
    if (!user) return safeJson({ ok: false, reason: 'unauthorized' }, 401);
    const supabase = adminClient();

    const body = await req.json();
    const requestedRole = body.role || body.selected_role;
    const role = requestedRole === 'broker' ? 'broker_owner' : requestedRole;
    const profileData = { ...body };
    delete profileData.role;
    delete profileData.selected_role;

    // 2. Validate role
    const allowedRoles = ['broker_owner', 'broker_agent', 'sourcing_manager', 'caller'];
    if (!role || !allowedRoles.includes(role)) {
      if (role === 'admin' || role === 'developer_admin') {
        return safeJson({
          ok: false,
          status: 'access_request_submitted',
          reason: 'admin_access_requires_approval',
        });
      }
      return safeJson({ ok: false, reason: 'invalid_role' }, 400);
    }

    if (role === 'caller') {
      const prodInvite = Deno.env.get('CALLER_INVITE_CODE');
      const uatInvite = Deno.env.get('UAT_CALLER_INVITE_CODE');
      const inviteCode = (prodInvite || uatInvite || "").trim();

      if (!inviteCode) {
        return safeJson({ ok: false, reason: 'caller_invite_not_configured' }, 503);
      }
      if (!profileData.invite_code || profileData.invite_code !== inviteCode) {
        return safeJson({ ok: false, reason: 'invalid_invite_code' }, 403);
      }
    }

    // 3. Resolve the org from the first active organization in the system.
    // This is safe because all brokers within a platform share one org.
    // In a multi-org future, this would be passed from the invite link.
    const { data: orgs, error: orgError } = await supabase
      .from('organizations')
      .select('id, status')
      .eq('status', 'active')
      .limit(1)
      .single();

    if (orgError || !orgs) throw new Error('organization_unavailable');
    const orgId: string = orgs.id;
    const permissionTemplateId = await defaultTemplateForRole(supabase, orgId, role, user.id);
    if (!permissionTemplateId) throw new Error('permission_template_unavailable');

    // 4. Assign Role - upsert by (user_id) with explicit conflict target
    const { error: roleErr } = await supabase.from('role_assignments').upsert(
      {
        user_id: user.id,
        role_id: role,
        organization_id: orgId,
        permission_template_id: permissionTemplateId,
        status: 'active',
      },
      { onConflict: 'user_id' }
    );
    if (roleErr) throw new Error('role_assignment_failed');

    // 5. Add/update pilot_users - upsert by (user_id) with explicit conflict target
    const { error: pilotErr } = await supabase.from('pilot_users').upsert(
      {
        user_id: user.id,
        role: legacyRole(role),
        status: 'active',
        org_id: orgId,
      },
      { onConflict: 'user_id' }
    );
    if (pilotErr) throw new Error('pilot_user_setup_failed');

    // 6. Create role-specific profile
    if (role === 'broker_owner' || role === 'broker_agent') {
      // Check if this user already has a broker profile
      const { data: existingBroker } = await supabase
        .from('brokers_public')
        .select('id, linked_user_id, broker_code')
        .eq('linked_user_id', user.id)
        .maybeSingle();

      if (existingBroker) {
        // User already onboarded - update profile fields only, do NOT create a new broker.
        const { error: updateErr } = await supabase
          .from('brokers_public')
          .update({
            broker_name: profileData.full_name || user.email?.split('@')[0],
            company_name: profileData.company_name || existingBroker['company_name'],
            area: profileData.area || existingBroker['area'],
            city: profileData.city || existingBroker['city'],
            status: 'active',
          })
          .eq('id', existingBroker.id);

        if (updateErr) throw new Error('profile_update_failed');
      } else {
        // New broker - generate unique broker_code and INSERT (never upsert without conflict key)
        let brokerCode = generateBrokerCode(profileData.company_name || profileData.full_name || '');

        // Find an active sourcing manager to assign this broker to
        const { data: manager } = await supabase
          .from('pilot_users')
          .select('user_id')
          .eq('role', 'sourcing_manager')
          .eq('status', 'active')
          .limit(1)
          .single();

        if (!manager) throw new Error('sourcing_manager_unavailable');

        // Retry if code collides (extremely rare)
        for (let i = 0; i < 5; i++) {
          const { data: codeCheck } = await supabase
            .from('brokers_public')
            .select('id')
            .eq('broker_code', brokerCode)
            .maybeSingle();
          if (!codeCheck) break;
          brokerCode = generateBrokerCode(profileData.company_name || profileData.full_name || '');
        }

        const { error: insertErr } = await supabase.from('brokers_public').insert({
          linked_user_id: user.id,
          organization_id: orgId,
          assigned_sourcing_manager_id: manager.user_id,
          broker_name: profileData.full_name || user.email?.split('@')[0],
          broker_alias: profileData.full_name || user.email?.split('@')[0],
          company_name: profileData.company_name || '',
          area: profileData.area || '',
          city: profileData.city || 'Mumbai',
          broker_code: brokerCode,
          status: 'active',
          verified_status: 'verified_active',
          verified_performance_rank: 'Silver',
          trust_score: 50,
        });

        if (insertErr) throw new Error('broker_profile_creation_failed');
      }

    } else if (role === 'sourcing_manager') {
      // Sourcing manager upsert - conflict on linked_user_id
      const { error: smErr } = await supabase.from('sourcing_managers_public').upsert(
        {
          linked_user_id: user.id,
          organization_id: orgId,
          manager_name: profileData.full_name || user.email?.split('@')[0],
          city: profileData.city || 'Mumbai',
          status: 'active',
        },
        { onConflict: 'linked_user_id' }
      );
      if (smErr) throw new Error('sourcing_manager_profile_failed');
    } else if (role === 'caller') {
      const { error: callerErr } = await supabase.from('caller_profiles').upsert(
        {
          linked_user_id: user.id,
          organization_id: orgId,
          caller_name: profileData.full_name || user.email?.split('@')[0],
          city: profileData.city || 'Mumbai',
          status: 'active',
        },
        { onConflict: 'linked_user_id' }
      );
      if (callerErr) throw new Error('caller_profile_failed');
    }

    const { error: auditErr } = await supabase.from('audit_events').insert({
      actor_id: user.id,
      event_type: 'user_onboarded',
      event_context: {
        organization_id: orgId,
        target_user_id: user.id,
        role,
      },
    });
    if (auditErr) throw new Error('onboarding_audit_failed');

    return safeJson({ ok: true, success: true, role });

  } catch (_err) {
    return safeJson({ ok: false, reason: 'onboarding_failed' }, 400);
  }
});
