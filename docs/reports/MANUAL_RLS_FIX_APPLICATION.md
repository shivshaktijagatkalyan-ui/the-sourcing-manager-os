# MANUAL FIX APPLICATION INSTRUCTIONS
## Apply RLS Fixes via Supabase Dashboard

**Status:** Ready to apply  
**Time:** 5-10 minutes  
**Risk:** LOW (all additions, no breaking changes)

---

## Quick Start

1. **Open Supabase Dashboard:**
   ```
   https://app.supabase.com/project/gblvnjilpcxhygvzikwe
   ```

2. **Go to SQL Editor** (left sidebar)

3. **Copy entire migration below**

4. **Paste into SQL Editor**

5. **Click RUN**

6. **Verify:** All statements executed (no red errors)

7. **Then:** `node scripts/debug-authenticated-broker-rls.mjs`

---

## SQL Migration to Paste

Copy everything from `==== START ====` to `==== END ====`

```sql
==== START ====

-- MIGRATION: Fix Authenticated Broker RLS Issues
-- Date: 2026-05-18
-- Purpose: Add missing schema elements for broker-to-user linking

-- ============================================================
-- FIX #1: Add missing owner_user_id column to brokers_public
-- ============================================================

ALTER TABLE public.brokers_public
ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id);

CREATE INDEX IF NOT EXISTS idx_brokers_public_owner_user_id
ON public.brokers_public(owner_user_id);

CREATE INDEX IF NOT EXISTS idx_brokers_public_organization_id
ON public.brokers_public(organization_id);

-- ============================================================
-- FIX #2: Create is_linked_broker_user() function (2-param)
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_linked_broker_user(p_broker_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.brokers_public bp
    WHERE bp.id = p_broker_id
      AND bp.owner_user_id = p_user_id
      AND EXISTS (
        SELECT 1
        FROM public.pilot_users pu
        WHERE pu.user_id = p_user_id
          AND pu.status = 'active'
          AND pu.role IN ('broker', 'broker_owner')
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_linked_broker_user(uuid, uuid) 
TO authenticated, service_role;

-- ============================================================
-- FIX #3: Create is_linked_broker_user() function (1-param)
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_linked_broker_user(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.brokers_public bp
    WHERE bp.owner_user_id = p_user_id
      AND EXISTS (
        SELECT 1
        FROM public.pilot_users pu
        WHERE pu.user_id = p_user_id
          AND pu.status = 'active'
          AND pu.role IN ('broker', 'broker_owner')
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_linked_broker_user(uuid) 
TO authenticated, service_role;

-- ============================================================
-- FIX #4: Create has_active_data_loan() function
-- ============================================================

CREATE OR REPLACE FUNCTION public.has_active_data_loan(p_lead_id uuid, p_user_id uuid, p_purpose text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.data_loans dl
    WHERE dl.lead_id = p_lead_id
      AND dl.granted_to_user_id = p_user_id
      AND dl.purpose = p_purpose
      AND dl.status = 'active'
      AND dl.starts_at <= now()
      AND dl.expires_at > now()
      AND dl.revoked_at IS NULL
  );
$$;

GRANT EXECUTE ON FUNCTION public.has_active_data_loan(uuid, uuid, text) 
TO authenticated, service_role;

-- ============================================================
-- FIX #5: Create broker_can_insert_lead() helper function
-- ============================================================

CREATE OR REPLACE FUNCTION public.broker_can_insert_lead(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.pilot_users pu
    WHERE pu.user_id = p_user_id
      AND pu.status = 'active'
      AND pu.role IN ('broker', 'broker_owner')
  );
$$;

GRANT EXECUTE ON FUNCTION public.broker_can_insert_lead(uuid) 
TO authenticated, service_role;

-- ============================================================
-- FIX #6: Add INSERT policy for brokers on leads_public
-- ============================================================

DROP POLICY IF EXISTS leads_public_broker_insert ON public.leads_public;
CREATE POLICY leads_public_broker_insert
ON public.leads_public
FOR INSERT
TO authenticated
WITH CHECK (
  public.broker_can_insert_lead(auth.uid())
  AND broker_id = (
    SELECT bp.id
    FROM public.brokers_public bp
    WHERE bp.owner_user_id = auth.uid()
    LIMIT 1
  )
);

-- ============================================================
-- FIX #7: Create get_user_broker_id() helper function
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_user_broker_id(p_user_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id
  FROM public.brokers_public
  WHERE owner_user_id = p_user_id
    AND EXISTS (
      SELECT 1
      FROM public.pilot_users pu
      WHERE pu.user_id = p_user_id
        AND pu.status = 'active'
    )
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.get_user_broker_id(uuid) 
TO authenticated, service_role;

-- ============================================================
-- ALL FIXES APPLIED
-- ============================================================

==== END ====
```

---

## Step-by-Step Screenshots

### Step 1: Open Supabase Dashboard
- Go to: https://app.supabase.com/project/gblvnjilpcxhygvzikwe
- Click "SQL Editor" (left sidebar)

### Step 2: Create New Query
- Click "New Query"

### Step 3: Paste SQL
- Copy everything between `==== START ====` and `==== END ====` above
- Paste into the query editor

### Step 4: Run
- Click blue "RUN" button
- OR press Cmd+Enter (Mac) / Ctrl+Enter (Windows/Linux)

### Step 5: Verify
- Look for green "Success" indicators
- Should see messages like:
  - `ALTER TABLE successfully applied`
  - `CREATE INDEX successfully applied`
  - `CREATE FUNCTION successfully applied`
  - `GRANT successfully applied`

### Step 6: Check for Errors
- Red error messages mean something failed
- If you see errors, try running the SQL again
- If still failing, each statement can be run individually

---

## Verification Checklist

After running SQL, verify in Supabase Dashboard:

**Tables Tab:**
- [ ] `brokers_public` table exists
- [ ] New columns: `owner_user_id`, `organization_id` visible

**Functions Tab:**
- [ ] `is_linked_broker_user` (2 versions - check both)
- [ ] `has_active_data_loan`
- [ ] `broker_can_insert_lead`
- [ ] `get_user_broker_id`

**Policies Tab (leads_public):**
- [ ] `leads_public_broker_insert` policy exists

---

## Troubleshooting

### Error: "Function already exists"
**Fix:** This is OK! The functions use `CREATE OR REPLACE`, so re-running is safe. The error means it's updating an existing function.

### Error: "Column already exists"
**Fix:** This is OK! The columns use `IF NOT EXISTS`, so re-running is safe. The error is informational.

### Error: "Policy already exists"
**Fix:** The script includes `DROP POLICY IF EXISTS` first, so this shouldn't happen. If it does, run again.

### Red errors everywhere
**Fix:** 
1. Check that you're in the right project (gblvnjilpcxhygvzikwe)
2. Check that Supabase is online (check status page)
3. Try running one statement at a time instead of all together

---

## After Running

### Option A: Run Debug Script Immediately
```bash
node scripts/debug-authenticated-broker-rls.mjs
```

Expected output should show:
```
✅ AUTH SUCCESS
✅ ROLE FOUND
✅ PILOT USER ACTIVE
✅ BROKER PROFILE FOUND
✅ LINKED BROKER
✅ FUNCTION SUCCESS
✅ LEAD CREATED
```

### Option B: Wait 30 Seconds First
Database caches take a moment to refresh. If debug script shows errors, wait 30 seconds and try again.

---

## Still Having Issues?

1. **Screenshot the error** and share
2. **Copy the exact error message** and share
3. **Verify project ID** is `gblvnjilpcxhygvzikwe`
4. **Verify you're in SQL Editor** (not Settings or elsewhere)
5. **Check Supabase status page** for outages

---

## Timeline

- **Paste & Run:** 2 minutes
- **Verify:** 1 minute
- **Debug test:** 30 seconds
- **Total:** ~5 minutes

---

**Next:** After fixes applied, run debug script to confirm all 5 issues resolved.

Then complete Phase 7 UAT → Mark as PASS → Resume launch.
