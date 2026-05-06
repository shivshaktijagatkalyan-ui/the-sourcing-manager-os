-- Allow incident response lockdown telemetry to be recorded through the
-- existing abuse-event ledger without widening access to sensitive data.

ALTER TABLE public.abuse_events
  DROP CONSTRAINT IF EXISTS abuse_events_event_type_check;

ALTER TABLE public.abuse_events
  ADD CONSTRAINT abuse_events_event_type_check CHECK (event_type IN (
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
    'paused_org_access_attempt',
    'emergency_lockdown_triggered'
  ));

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
        'paused_org_access_attempt',
        'emergency_lockdown_triggered'
    ) THEN
        RAISE EXCEPTION 'invalid_event_type';
    END IF;

    IF p_severity NOT IN ('low', 'medium', 'high', 'critical') THEN
        RAISE EXCEPTION 'invalid_severity';
    END IF;

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
        'accuracy_meters',
        'action',
        'reason_recorded'
    )
    AND jsonb_typeof(value) IN ('string', 'number', 'boolean', 'null');

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
        p_risk_delta,
        v_safe_evidence
    )
    RETURNING id INTO v_abuse_id;

    IF p_severity IN ('high', 'critical') THEN
        INSERT INTO public.risk_notifications (
            organization_id,
            abuse_event_id,
            notification_type,
            title,
            body,
            severity,
            status,
            created_for_role
        ) VALUES (
            v_org_id,
            v_abuse_id,
            'abuse_event',
            'Risk event flagged',
            'A high-risk operational event requires admin review.',
            p_severity,
            'pending',
            'platform_admin'
        );
    END IF;

    INSERT INTO public.audit_events (
        actor_id,
        event_type,
        event_context
    ) VALUES (
        p_actor_id,
        'abuse_event_flagged',
        jsonb_build_object(
            'abuse_event_id', v_abuse_id,
            'event_type', p_event_type,
            'severity', p_severity,
            'organization_id', v_org_id
        )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.record_pilot_abuse(uuid, text, text, numeric, jsonb, uuid, uuid) FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.record_pilot_abuse(uuid, text, text, numeric, jsonb, uuid, uuid) TO service_role;
