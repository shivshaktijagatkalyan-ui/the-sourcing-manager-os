-- Migration: 20260510000000_add_vapi_provider.sql
-- Description: Updates call_attempts table to support autonomous AI Voice Agents.

-- 1. Make caller_id nullable to support system-initiated calls
ALTER TABLE public.call_attempts ALTER COLUMN caller_id DROP NOT NULL;

-- 2. Drop existing constraints to update them
ALTER TABLE public.call_attempts DROP CONSTRAINT IF EXISTS call_attempts_provider_check;
ALTER TABLE public.call_attempts DROP CONSTRAINT IF EXISTS call_attempts_status_check;

-- 3. Re-add constraints with Vapi and AI statuses
ALTER TABLE public.call_attempts 
ADD CONSTRAINT call_attempts_provider_check 
CHECK (provider IN ('exotel', 'twilio', 'vapi_ai', 'bland_ai'));

ALTER TABLE public.call_attempts 
ADD CONSTRAINT call_attempts_status_check 
CHECK (
  call_status IN (
    'connecting', 'queued', 'blocked', 'expired', 'revoked', 
    'dnd_blocked', 'consent_required', 'provider_failed', 
    'completed', 'failed', 'ai_queued', 'ai_in_progress', 
    'ai_provider_failed', 'config_error'
  )
);

-- 4. Record the infrastructure upgrade in audit logs
COMMENT ON TABLE public.call_attempts IS 'Stores both human and AI-initiated call attempts with strict governance.';
