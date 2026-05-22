-- Migration: Add RERA number column to public.brokers_public
-- MIG-001: Add column with format constraint
ALTER TABLE public.brokers_public
  ADD COLUMN IF NOT EXISTS rera_number TEXT;

-- CHECK constraint: RERA must start with 1–3 letters followed by 8+ alphanumeric/hyphen chars
-- Allows NULL (optional for brokers not yet RERA-registered)
ALTER TABLE public.brokers_public
  DROP CONSTRAINT IF EXISTS brokers_public_rera_number_format;

ALTER TABLE public.brokers_public
  ADD CONSTRAINT brokers_public_rera_number_format
  CHECK (
    rera_number IS NULL
    OR rera_number ~ '^[A-Z]{1,3}[0-9A-Z\-]{8,}$'
  );

-- MIG-002: Index for fast RERA lookups (uniqueness enforced via application layer)
CREATE INDEX IF NOT EXISTS idx_brokers_public_rera_number
  ON public.brokers_public (rera_number)
  WHERE rera_number IS NOT NULL;

-- MIG-001 (RLS): Policy allowing a broker to set their own rera_number.
-- Only the linked user can update it via the Edge Function (which runs as service_role).
-- This policy scopes direct-write access for admin tooling that respects RLS.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'brokers_public'
      AND policyname = 'broker_can_update_own_rera'
  ) THEN
    CREATE POLICY broker_can_update_own_rera
      ON public.brokers_public
      FOR UPDATE
      USING (linked_user_id = auth.uid())
      WITH CHECK (linked_user_id = auth.uid());
  END IF;
END;
$$;
