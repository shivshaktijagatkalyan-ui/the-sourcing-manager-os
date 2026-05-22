-- Migration: 20260510000300_broker_isolation_fix.sql
-- CRITICAL: Fixes broker account isolation bug.
-- Root causes addressed:
--   1. is_linked_broker_user() JOIN on organization_id failed when org_id was NULL (new signups had NULL org)
--   2. broker_locks RLS policy used source_site_visit_id which could be NULL, blocking all reads
--   3. role_assignments had no unique constraint on user_id, allowing duplicate role rows
--   4. leads_public old policy 'leads_public_broker_read' used broker_id = auth.uid() (user_id, not broker id)

-- =========================================================
-- 1. Patch is_linked_broker_user to handle null organization_id gracefully
-- =========================================================
CREATE OR REPLACE FUNCTION public.is_linked_broker_user(
  p_broker_id uuid,
  p_user_id uuid
) RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.brokers_public bp
    WHERE bp.id = p_broker_id
      AND bp.linked_user_id = p_user_id
      AND bp.status = 'active'
      AND (
        -- If org is set, verify pilot membership; if org is NULL (legacy/broken row), 
        -- allow by user link only (will be self-healed by re-onboarding)
        bp.organization_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.pilot_users pu
          WHERE pu.user_id = p_user_id
            AND pu.org_id = bp.organization_id
            AND pu.status = 'active'
        )
      )
  );
$$;

-- =========================================================
-- 2. Fix broker_locks RLS — was gated on source_site_visit_id IS NOT NULL
--    which blocked all locks created without a visit reference.
--    Replace with direct broker_id link.
-- =========================================================
DROP POLICY IF EXISTS broker_locks_linked_source_broker_read ON public.broker_locks;
CREATE POLICY broker_locks_linked_source_broker_read
ON public.broker_locks
FOR SELECT TO authenticated
USING (
  public.is_linked_broker_user(broker_id, auth.uid())
);

-- Also add a direct broker_id self-read fallback
DROP POLICY IF EXISTS broker_locks_broker_read ON public.broker_locks;
CREATE POLICY broker_locks_broker_read
ON public.broker_locks
FOR SELECT TO authenticated
USING (broker_id = auth.uid());

-- =========================================================
-- 3. Fix the legacy leads_public_broker_read policy
--    broker_id column is the auth.users.id of the SM who uploaded the lead 
--    (not the source broker). source_broker_id is the brokers_public.id.
--    This policy was wrong — it allowed any authenticated user who matched 
--    broker_id (the uploader) to read ALL leads with their user_id as broker_id.
--    This is not a broker isolation issue per se but could leak SM-uploaded leads.
-- =========================================================
DROP POLICY IF EXISTS leads_public_broker_read ON public.leads_public;

-- =========================================================
-- 4. Ensure unique constraint on role_assignments(user_id)
--    Without this, upsert without onConflict creates duplicate rows causing 
--    role_resolver to pick the first (which might be stale).
-- =========================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_role_assignments_user_id_unique
ON public.role_assignments(user_id);

-- =========================================================
-- 5. Backfill: Set organization_id on any broker rows that have linked_user_id
--    but NULL organization_id, using pilot_users to find their org.
-- =========================================================
UPDATE public.brokers_public bp
SET organization_id = pu.org_id
FROM public.pilot_users pu
WHERE bp.linked_user_id = pu.user_id
  AND bp.organization_id IS NULL
  AND pu.status = 'active';

-- =========================================================
-- 6. Backfill: Generate broker_code for any brokers missing it
-- =========================================================
UPDATE public.brokers_public
SET broker_code = UPPER(
  SUBSTRING(REGEXP_REPLACE(COALESCE(broker_name, broker_alias, 'BK'), '[^A-Za-z0-9]', '', 'g'), 1, 4)
  || TO_CHAR(NOW(), 'MMDD')
  || LPAD(FLOOR(RANDOM() * 9000 + 1000)::TEXT, 4, '0')
)
WHERE broker_code IS NULL OR broker_code = '';

-- =========================================================
-- 7. Verify pilot_users unique constraint
-- =========================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_pilot_users_user_id_unique
ON public.pilot_users(user_id);

-- =========================================================
-- 8. Audit log for this migration
-- =========================================================
COMMENT ON FUNCTION public.is_linked_broker_user(uuid, uuid) IS 
'Returns true if p_user_id is the linked_user_id of broker p_broker_id and is active. 
Now handles NULL organization_id gracefully for legacy/incomplete onboarding rows.';
