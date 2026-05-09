-- Sprint 8 Part 2: Smart Priority Queue Infrastructure
-- Updating update_lead_call_outcome RPC to support callback_at

CREATE OR REPLACE FUNCTION public.update_lead_call_outcome(
  p_lead_id uuid,
  p_outcome text,
  p_notes text,
  p_next_followup timestamptz DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_org_id uuid;
  v_source_broker_id uuid;
  v_next_status text;
  v_is_terminal boolean;
BEGIN
  -- 1. Verify caller has access
  IF NOT EXISTS (
    SELECT 1
    FROM public.leads_public
    WHERE id = p_lead_id
      AND (assigned_caller_id = auth.uid() OR public.has_active_data_loan(id, auth.uid(), 'call'))
  ) THEN
    RAISE EXCEPTION 'access_denied';
  END IF;

  SELECT organization_id, source_broker_id
    INTO v_org_id, v_source_broker_id
  FROM public.leads_public
  WHERE id = p_lead_id;

  v_is_terminal := p_outcome IN ('not_interested', 'wrong_lead', 'budget_mismatch', 'location_mismatch');

  v_next_status := CASE p_outcome
    WHEN 'interested' THEN 'interested'
    WHEN 'call_later' THEN 'call_later'
    WHEN 'not_reachable' THEN 'not_reachable'
    WHEN 'wrong_lead' THEN 'wrong_lead'
    WHEN 'budget_mismatch' THEN 'budget_mismatch'
    WHEN 'location_mismatch' THEN 'location_mismatch'
    WHEN 'visit_scheduled' THEN 'visit_scheduled'
    WHEN 'not_interested' THEN 'revoked'
    ELSE 'loan_active'
  END;

  -- 2. Update Lead
  UPDATE public.leads_public
  SET last_call_outcome = p_outcome,
      last_call_at = now(),
      lead_status = v_next_status,
      callback_at = p_next_followup, -- Map p_next_followup to callback_at for queue sorting
      updated_at = now()
  WHERE id = p_lead_id;

  -- 3. Record Call Attempt
  INSERT INTO public.call_attempts (
    lead_id,
    caller_id,
    call_status,
    outcome,
    created_at
  ) VALUES (
    p_lead_id,
    auth.uid(),
    'completed',
    p_outcome,
    now()
  );

  -- 4. If terminal, revoke data loan
  IF v_is_terminal THEN
    UPDATE public.data_loans
    SET status = 'revoked',
        revoked_at = now()
    WHERE lead_id = p_lead_id
      AND granted_to_user_id = auth.uid()
      AND purpose = 'call'
      AND status = 'active';
  END IF;

  -- 5. Broker Activity Log
  IF v_source_broker_id IS NOT NULL THEN
    INSERT INTO public.broker_activity_logs (
      organization_id,
      broker_id,
      actor_id,
      activity_type,
      outcome,
      notes_safe,
      next_followup_at
    ) VALUES (
      v_org_id,
      v_source_broker_id,
      auth.uid(),
      CASE WHEN p_outcome = 'interested' THEN 'lead_received' ELSE 'call_connected' END,
      p_outcome,
      p_notes,
      p_next_followup
    );
  END IF;

  -- 6. Audit
  INSERT INTO public.audit_events (
    actor_id,
    lead_id,
    event_type,
    event_context
  ) VALUES (
    auth.uid(),
    p_lead_id,
    'lead_call_outcome_updated',
    jsonb_build_object('outcome', p_outcome, 'is_terminal', v_is_terminal, 'callback_at', p_next_followup)
  );

  RETURN true;
END;
$$;
