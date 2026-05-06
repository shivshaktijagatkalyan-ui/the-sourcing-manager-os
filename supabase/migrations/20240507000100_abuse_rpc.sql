-- Sprint 4: Centralized Abuse Flagging RPC (Fixed Schema)
CREATE OR REPLACE FUNCTION public.record_pilot_abuse(
    p_actor_id uuid,
    p_event_type text,
    p_severity text,
    p_risk_delta numeric,
    p_evidence_ref jsonb DEFAULT '{}'::jsonb,
    p_lead_id uuid DEFAULT NULL,
    p_visit_id uuid DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_org_id uuid;
    v_abuse_id uuid;
    v_safe_evidence jsonb;
BEGIN
    IF p_event_type NOT IN (
        'gps_outside_geofence_repeated',
        'gps_accuracy_failure_repeated',
        'photo_overwrite_attempt',
        'call_after_loan_expiry',
        'revoked_loan_access_attempt',
        'duplicate_lock_attempt',
        'broker_rejection_spike',
        'dispute_frequency_spike',
        'inactive_enabled_user',
        'unusual_activity_window',
        'disabled_user_access_attempt',
        'paused_org_access_attempt'
    ) THEN
        RAISE EXCEPTION 'invalid_event_type';
    END IF;

    IF p_severity NOT IN ('low', 'medium', 'high', 'critical') THEN
        RAISE EXCEPTION 'invalid_severity';
    END IF;

    -- 1. Identify organization
    SELECT org_id INTO v_org_id FROM public.pilot_users WHERE user_id = p_actor_id LIMIT 1;
    
    IF v_org_id IS NULL THEN
        RETURN;
    END IF;

    SELECT COALESCE(jsonb_object_agg(key, value), '{}'::jsonb)
    INTO v_safe_evidence
    FROM jsonb_each(COALESCE(p_evidence_ref, '{}'::jsonb))
    WHERE key IN (
        'source',
        'count',
        'status',
        'reason_code',
        'loan_id',
        'visit_id',
        'event_count',
        'activity_date',
        'distance_meters',
        'accuracy_meters'
    )
    AND jsonb_typeof(value) IN ('string', 'number', 'boolean', 'null');

    -- 2. Insert Abuse Event
    INSERT INTO public.abuse_events (
        actor_id,
        organization_id,
        lead_id,
        site_visit_id,
        event_type,
        severity,
        risk_score_delta,
        evidence_ref
    ) VALUES (
        p_actor_id,
        v_org_id,
        p_lead_id,
        p_visit_id,
        p_event_type,
        p_severity,
        GREATEST(-5, LEAST(5, COALESCE(p_risk_delta, 0))),
        COALESCE(v_safe_evidence, '{}'::jsonb)
    ) RETURNING id INTO v_abuse_id;

    -- 3. Trigger Risk Notification for high/critical events
    IF p_severity IN ('high', 'critical') THEN
        INSERT INTO public.risk_notifications (
            organization_id,
            abuse_event_id,
            severity,
            notification_type,
            reason_code
        ) VALUES (
            v_org_id,
            v_abuse_id,
            p_severity,
            CASE 
                WHEN p_severity = 'critical' THEN 'critical_abuse_event'
                WHEN p_event_type IN ('gps_outside_geofence_repeated', 'gps_accuracy_failure_repeated') THEN 'gps_rejection_repeated'
                WHEN p_event_type = 'duplicate_lock_attempt' THEN 'duplicate_lock_conflict'
                WHEN p_event_type = 'broker_rejection_spike' THEN 'broker_rejection_spike'
                WHEN p_event_type = 'paused_org_access_attempt' THEN 'org_paused'
                WHEN p_event_type = 'dispute_frequency_spike' THEN 'dispute_escalated'
                ELSE 'critical_abuse_event'
            END,
            p_event_type
        );
    END IF;

    -- 4. Log Audit Event
    INSERT INTO public.audit_events (
        actor_id,
        lead_id,
        event_type,
        event_context
    ) VALUES (
        p_actor_id,
        p_lead_id,
        'abuse_event_flagged',
        jsonb_build_object(
            'event_type', p_event_type,
            'severity', p_severity,
            'organization_id', v_org_id,
            'abuse_event_id', v_abuse_id
        )
    );

    IF p_severity = 'critical' THEN
        INSERT INTO public.audit_events (
            actor_id,
            lead_id,
            event_type,
            event_context
        ) VALUES (
            p_actor_id,
            p_lead_id,
            'user_freeze_recommended',
            jsonb_build_object(
                'organization_id', v_org_id,
                'abuse_event_id', v_abuse_id,
                'event_type', p_event_type
            )
        );
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.record_pilot_abuse(uuid, text, text, numeric, jsonb, uuid, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.record_pilot_abuse(uuid, text, text, numeric, jsonb, uuid, uuid) TO service_role;
