-- Practical MVP v0.1: Step 8 - Caller Support for Broker Leads
-- Migration: 20240516000000_caller_workflow_support.sql

-- 1. Ensure leads_public has necessary fields for caller assignment
ALTER TABLE public.leads_public
  ADD COLUMN IF NOT EXISTS assigned_caller_id uuid REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS call_priority text NOT NULL DEFAULT 'normal' CHECK (call_priority IN ('low', 'normal', 'high', 'urgent')),
  ADD COLUMN IF NOT EXISTS last_call_outcome text,
  ADD COLUMN IF NOT EXISTS last_call_at timestamptz;

-- 2. Trigger to automatically create data_loan on assignment
CREATE OR REPLACE FUNCTION public.auto_create_data_loan_on_assignment()
RETURNS trigger AS $$
BEGIN
  -- If assigned_caller_id changes and is not null
  IF (NEW.assigned_caller_id IS NOT NULL AND (OLD.assigned_caller_id IS NULL OR OLD.assigned_caller_id <> NEW.assigned_caller_id)) THEN
    -- Create a 24-hour data loan for the caller
    INSERT INTO public.data_loans (
      lead_id,
      broker_id, -- Original lead owner/broker (if internal)
      granted_to_user_id,
      purpose,
      status,
      starts_at,
      expires_at
    ) VALUES (
      NEW.id,
      NEW.broker_id, 
      NEW.assigned_caller_id,
      'call',
      'active',
      now(),
      now() + interval '24 hours'
    );
    
    -- Log the assignment as a broker activity if it's broker-sourced
    IF (NEW.source_broker_id IS NOT NULL) THEN
      INSERT INTO public.broker_activity_logs (
        organization_id,
        broker_id,
        project_id,
        actor_id,
        activity_type,
        notes_safe
      ) VALUES (
        NEW.organization_id,
        NEW.source_broker_id,
        NEW.project_id,
        auth.uid(),
        'note_added',
        'Lead assigned to caller for verification.'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trigger_auto_data_loan
BEFORE UPDATE ON public.leads_public
FOR EACH ROW EXECUTE FUNCTION public.auto_create_data_loan_on_assignment();

-- 3. RLS for Caller Lead Access
DROP POLICY IF EXISTS leads_public_caller_assigned_read ON public.leads_public;
CREATE POLICY leads_public_caller_assigned_read ON public.leads_public
FOR SELECT TO authenticated
USING (
  assigned_caller_id = auth.uid()
  OR public.has_active_data_loan(id, auth.uid(), 'call')
);

-- 4. Function for Caller to update lead outcome securely
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
BEGIN
  -- 1. Verify caller has access
  IF NOT EXISTS (
    SELECT 1 FROM public.leads_public 
    WHERE id = p_lead_id AND assigned_caller_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'access_denied';
  END IF;

  SELECT organization_id, source_broker_id INTO v_org_id, v_source_broker_id
  FROM public.leads_public WHERE id = p_lead_id;

  -- 2. Update lead status based on outcome
  UPDATE public.leads_public
  SET 
    last_call_outcome = p_outcome,
    last_call_at = now(),
    lead_status = CASE 
      WHEN p_outcome IN ('interested', 'visit_scheduled') THEN 'locked' -- Progress to SM
      WHEN p_outcome = 'not_interested' THEN 'revoked'
      ELSE lead_status
    END,
    updated_at = now()
  WHERE id = p_lead_id;

  -- 3. Record call attempt
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

  -- 4. If broker-sourced, update broker activity
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
      CASE 
        WHEN p_outcome = 'interested' THEN 'lead_received' -- Upgrading status
        ELSE 'call_connected'
      END,
      p_outcome,
      p_notes,
      p_next_followup
    );
  END IF;

  RETURN true;
END;
$$;
