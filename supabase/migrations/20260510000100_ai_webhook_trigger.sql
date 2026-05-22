-- Migration: 20260510000100_ai_webhook_trigger.sql
-- Description: Automates AI Voice calling on lead creation.

-- 1. Enable pg_net extension (Supabase standard for async networking)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- 2. Create the Trigger Function
-- This function sends an async HTTP POST to the ai-lead-response Edge Function.
CREATE OR REPLACE FUNCTION public.on_lead_created_trigger_ai_call()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_supabase_url TEXT;
  v_service_role_key TEXT;
BEGIN
  -- We assume these are set as custom settings in the database or hardcoded during deployment.
  -- In production, these should be set via: ALTER DATABASE postgres SET "app.settings.supabase_url" = '...';
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_role_key := current_setting('app.settings.service_role_key', true);

  -- Safety: If settings are missing, log a warning but don't crash the insertion
  IF v_supabase_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE WARNING 'AI Webhook skipped: app.settings.supabase_url or service_role_key not set.';
    RETURN NEW;
  END IF;

  -- 3. Execute the Async Call (The "Golden Window" trigger)
  -- This sends the lead_id to our AI handler immediately.
  PERFORM
    net.http_post(
      url := v_supabase_url || '/functions/v1/ai-lead-response',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_service_role_key
      ),
      body := jsonb_build_object(
        'lead_id', NEW.id,
        'source', 'autonomous_trigger_v1'
      )
    );

  RETURN NEW;
END;
$$;

-- 4. Attach the Trigger
-- We use AFTER INSERT to ensure the lead is fully persisted before the AI tries to fetch it.
DROP TRIGGER IF EXISTS trigger_ai_call_on_lead_insertion ON public.leads_public;
CREATE TRIGGER trigger_ai_call_on_lead_insertion
AFTER INSERT ON public.leads_public
FOR EACH ROW
WHEN (NEW.consent_status = 'granted') -- Only call if user has already given consent
EXECUTE FUNCTION public.on_lead_created_trigger_ai_call();

-- 5. Add Audit Log for the setup
COMMENT ON FUNCTION public.on_lead_created_trigger_ai_call() IS 'Autonomous trigger for AI Voice Agent qualification.';
