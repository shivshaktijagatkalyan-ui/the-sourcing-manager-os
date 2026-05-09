-- Fix pilot_users SELECT policy recursion.
-- The previous policy queried pilot_users from inside a pilot_users policy,
-- which caused PostgREST role/profile reads to fail with SQLSTATE 42P17.

DROP POLICY IF EXISTS "pilot_users_view_org" ON public.pilot_users;
DROP POLICY IF EXISTS "pilot_users_self_read" ON public.pilot_users;
DROP POLICY IF EXISTS "pilot_users_same_org_read" ON public.pilot_users;

CREATE POLICY "pilot_users_self_read"
ON public.pilot_users
FOR SELECT
TO authenticated
USING (
  user_id = auth.uid()
  AND status = 'active'
  AND NOT public.has_active_suspension(auth.uid())
);

CREATE POLICY "pilot_users_same_org_read"
ON public.pilot_users
FOR SELECT
TO authenticated
USING (
  public.is_same_active_pilot_org(auth.uid(), org_id)
  AND NOT public.has_active_suspension(auth.uid())
);
