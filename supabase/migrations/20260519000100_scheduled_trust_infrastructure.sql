-- FutureTrust OS — Scheduled Trust Infrastructure
-- Migration: 20260519000100_scheduled_trust_infrastructure.sql
-- Adds: pg_cron loan expiry, trust decay, abuse_events constraint gap fixes
-- All statements are idempotent.

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 1: Data Loan Auto-Expiry
-- Loans past their expires_at window must be marked expired automatically.
-- The Edge Function run-trust-decay cannot be the only path — if a cron job
-- runs this in DB, there is no dependency on network availability.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.expire_stale_data_loans()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count integer;
BEGIN
  UPDATE public.data_loans
  SET status = 'expired'
  WHERE status = 'active'
    AND revoked_at IS NULL
    AND expires_at <= now();

  GET DIAGNOSTICS v_expired_count = ROW_COUNT;

  -- Write a single system audit event per run (not per loan — avoids log bloat)
  IF v_expired_count > 0 THEN
    INSERT INTO public.audit_events (actor_id, lead_id, event_type, event_context)
    VALUES (
      NULL,
      NULL,
      'system_loan_expiry_run',
      jsonb_build_object(
        'expired_count', v_expired_count,
        'run_at', now()
      )
    );
  END IF;

  RETURN v_expired_count;
END;
$$;

-- Restrict execution: only service_role (Edge Functions) and pg_cron can call this
REVOKE ALL ON FUNCTION public.expire_stale_data_loans() FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.expire_stale_data_loans() TO service_role;

-- Performance index for the expiry query
CREATE INDEX IF NOT EXISTS idx_data_loans_expiry_scan
  ON public.data_loans (expires_at, status)
  WHERE status = 'active' AND revoked_at IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 2: Trust Score Decay Function
-- Inactive users (no audit activity in 30 days) receive a gentle decay.
-- This runs in DB to ensure it executes even when Edge Functions are cold-started.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.decay_inactive_trust_scores()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_decayed_count integer := 0;
  v_rec RECORD;
  v_new_score numeric(3,2);
  v_decay_amount numeric(3,2) := 0.05; -- Small decay per run cycle
BEGIN
  -- Target: active users with a trust score above floor (2.0) who have had
  -- no audit activity in 30 days. Do NOT decay users who are actively working.
  FOR v_rec IN
    SELECT
      ts.entity_id,
      ts.entity_type,
      ts.score,
      ts.organization_id
    FROM public.trust_scores ts
    WHERE ts.entity_type = 'user'
      AND ts.score > 2.00
      AND NOT EXISTS (
        SELECT 1
        FROM public.audit_events ae
        WHERE ae.actor_id = ts.entity_id
          AND ae.created_at >= now() - interval '30 days'
      )
  LOOP
    -- Clamp at 2.00 floor — never decay below minimum operational score
    v_new_score := GREATEST(2.00, v_rec.score - v_decay_amount);

    UPDATE public.trust_scores
    SET
      score = v_new_score,
      updated_at = now()
    WHERE entity_id = v_rec.entity_id
      AND entity_type = v_rec.entity_type;

    -- Record snapshot for explainability
    INSERT INTO public.trust_score_snapshots (
      entity_id,
      entity_type,
      organization_id,
      score_before,
      score_after,
      score_delta,
      reason_code
    ) VALUES (
      v_rec.entity_id,
      v_rec.entity_type,
      v_rec.organization_id,
      v_rec.score,
      v_new_score,
      v_new_score - v_rec.score,
      'inactivity_decay_30d'
    );

    v_decayed_count := v_decayed_count + 1;
  END LOOP;

  -- System-level audit for the decay run
  IF v_decayed_count > 0 THEN
    INSERT INTO public.audit_events (actor_id, lead_id, event_type, event_context)
    VALUES (
      NULL,
      NULL,
      'system_trust_decay_run',
      jsonb_build_object(
        'decayed_count', v_decayed_count,
        'decay_amount', v_decay_amount,
        'run_at', now()
      )
    );
  END IF;

  RETURN v_decayed_count;
END;
$$;

REVOKE ALL ON FUNCTION public.decay_inactive_trust_scores() FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.decay_inactive_trust_scores() TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 3: Broker Lock Auto-Expiry
-- broker_locks past expires_at must flip to 'expired' to unblock re-registration.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.expire_stale_broker_locks()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer;
BEGIN
  UPDATE public.broker_locks
  SET status = 'expired'
  WHERE status = 'active'
    AND expires_at <= now();

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_stale_broker_locks() FROM anon, authenticated, public;
GRANT EXECUTE ON FUNCTION public.expire_stale_broker_locks() TO service_role;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 4: pg_cron Schedule Wiring
-- Requires pg_cron extension enabled in Supabase dashboard (Database > Extensions).
-- These schedules are idempotent — safe to re-run on migration replay.
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  -- Only attempt scheduling if pg_cron is available
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN

    -- Loan expiry: every 15 minutes (catches loans expiring during active sessions)
    PERFORM cron.unschedule('futuretrust_expire_data_loans')
    WHERE EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'futuretrust_expire_data_loans'
    );

    PERFORM cron.schedule(
      'futuretrust_expire_data_loans',
      '*/15 * * * *',  -- every 15 minutes
      'SELECT public.expire_stale_data_loans()'
    );

    -- Trust decay: once per day at 02:30 IST (21:00 UTC)
    PERFORM cron.unschedule('futuretrust_trust_decay')
    WHERE EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'futuretrust_trust_decay'
    );

    PERFORM cron.schedule(
      'futuretrust_trust_decay',
      '0 21 * * *',  -- 21:00 UTC = 02:30 IST
      'SELECT public.decay_inactive_trust_scores()'
    );

    -- Broker lock expiry: once per hour
    PERFORM cron.unschedule('futuretrust_expire_broker_locks')
    WHERE EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'futuretrust_expire_broker_locks'
    );

    PERFORM cron.schedule(
      'futuretrust_expire_broker_locks',
      '0 * * * *',  -- top of every hour
      'SELECT public.expire_stale_broker_locks()'
    );

    RAISE NOTICE 'pg_cron jobs scheduled: futuretrust_expire_data_loans, futuretrust_trust_decay, futuretrust_expire_broker_locks';

  ELSE
    RAISE NOTICE 'pg_cron not available — scheduled functions created but not wired. Enable pg_cron in Supabase Dashboard > Database > Extensions.';
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 5: Fix abuse_events event_type constraint gap
-- initiate-call writes 'revoked_loan_access_attempt' and 'call_after_loan_expiry'
-- but these were missing from the sprint4 CHECK constraint, causing live insert errors.
-- ─────────────────────────────────────────────────────────────────────────────

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'abuse_events'
  ) THEN
    -- Drop old constraint
    ALTER TABLE public.abuse_events DROP CONSTRAINT IF EXISTS abuse_events_event_type_check;

    -- Re-add with all event types including those written by initiate-call
    ALTER TABLE public.abuse_events
    ADD CONSTRAINT abuse_events_event_type_check
    CHECK (event_type IN (
      -- Original sprint4 types
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
      -- Additional types written by Edge Functions
      'role_escalation_attempt',
      'rapid_multi_project_checkin',
      'duplicate_lead_submission',
      'gps_boundary_exceeded'
    ));
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- SECTION 6: audit_events event_type additions for system scheduled events
-- system_loan_expiry_run and system_trust_decay_run written by functions above
-- must not be blocked by any future event_type constraint added to audit_events.
-- (Currently audit_events has no CHECK on event_type — this comment is a guard
--  to ensure no future migration adds one without including these system events.)
-- ─────────────────────────────────────────────────────────────────────────────

COMMENT ON TABLE public.audit_events IS
  'Append-only operational audit ledger. event_type is unconstrained by design to '
  'allow new event types without migrations. System events: system_loan_expiry_run, '
  'system_trust_decay_run. All writes via Edge Functions or SECURITY DEFINER RPCs.';
