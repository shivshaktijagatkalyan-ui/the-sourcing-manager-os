-- Broker Dashboard Hardening – MIG-003
-- Resolves: BUG-C1, SCHEMA-1, SCHEMA-2, BUG-H5
-- All statements are idempotent.

-- ─────────────────────────────────────────────────────────────────────────────
-- BUG-C1: Fix broker_locks RLS – previous policy only granted access when
-- source_site_visit_id was non-null, making admin-created locks invisible.
-- New policy: allow access if broker_id matches directly OR via visit chain.
-- ─────────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS broker_locks_linked_source_broker_read ON public.broker_locks;
CREATE POLICY broker_locks_linked_source_broker_read
ON public.broker_locks
FOR SELECT TO authenticated
USING (
  -- Direct broker ownership match (covers admin-created locks)
  public.is_linked_broker_user(broker_id, auth.uid())
  OR
  -- Legacy visit-chain match (preserves backward compatibility)
  (
    source_site_visit_id IS NOT NULL
    AND public.is_linked_broker_visit(source_site_visit_id, auth.uid())
  )
);

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMA-1: Add RLS SELECT policy for site_visit_proposals so brokers
-- can see their own proposals in "MY VISIT PROPOSALS" section.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.site_visit_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_visit_proposals FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS svp_linked_broker_read ON public.site_visit_proposals;
CREATE POLICY svp_linked_broker_read
ON public.site_visit_proposals
FOR SELECT TO authenticated
USING (
  source_broker_id IS NOT NULL
  AND public.is_linked_broker_user(source_broker_id, auth.uid())
);

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMA-2: Add RLS SELECT policy for broker_followups so brokers
-- can see their own follow-ups in "MY FOLLOW-UPS" section.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'broker_followups'
  ) THEN
    EXECUTE 'ALTER TABLE public.broker_followups ENABLE ROW LEVEL SECURITY';
    EXECUTE 'ALTER TABLE public.broker_followups FORCE ROW LEVEL SECURITY';
    EXECUTE '
      DROP POLICY IF EXISTS broker_followups_linked_broker_read ON public.broker_followups;
      CREATE POLICY broker_followups_linked_broker_read
      ON public.broker_followups
      FOR SELECT TO authenticated
      USING (public.is_linked_broker_user(broker_id, auth.uid()))
    ';
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- BUG-H5: Add target_visits column to broker_goals if missing.
-- Referenced in the dashboard "Monthly Target" panel.
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'broker_goals'
  ) THEN
    -- Add target_visits column
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'broker_goals'
        AND column_name = 'target_visits'
    ) THEN
      ALTER TABLE public.broker_goals ADD COLUMN target_visits int NOT NULL DEFAULT 0;
    END IF;

    -- Ensure broker_goals has RLS for linked broker read
    EXECUTE 'ALTER TABLE public.broker_goals ENABLE ROW LEVEL SECURITY';
    EXECUTE 'ALTER TABLE public.broker_goals FORCE ROW LEVEL SECURITY';
    EXECUTE '
      DROP POLICY IF EXISTS broker_goals_linked_broker_read ON public.broker_goals;
      CREATE POLICY broker_goals_linked_broker_read
      ON public.broker_goals
      FOR SELECT TO authenticated
      USING (public.is_linked_broker_user(broker_id, auth.uid()))
    ';
  END IF;
END $$;
