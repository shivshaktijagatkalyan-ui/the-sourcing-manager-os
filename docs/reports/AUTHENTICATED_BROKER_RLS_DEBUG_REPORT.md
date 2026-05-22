# AUTHENTICATED BROKER RLS DEBUG REPORT
## Investigation of Lead Upload Permission Issues

**Date:** 2026-05-18  
**Status:** 🚫 BLOCKED — MULTIPLE ISSUES FOUND  
**Verdict:** B. BLOCKED — ROLE/LINKING/RLS ISSUE FOUND

---

## EXECUTIVE SUMMARY

The authenticated broker lead upload flow is **BLOCKED** at multiple critical points:

1. ❌ **Schema Mismatch** — Expected `brokers_public.owner_user_id` column does not exist
2. ❌ **Missing Function** — `is_linked_broker_user()` function not found in schema
3. ❌ **RLS Policy Error** — `has_active_data_loan()` function call failing in SELECT policy
4. ❌ **Edge Function Error** — `broker-upload-lead` returning non-2xx status code
5. ⚠️  **Role Assignment Structure** — System uses `pilot_users` table, not traditional `role_assignments`

**Impact:** Authenticated brokers cannot upload leads. The permission chain is broken.

---

## DETAILED FINDINGS

### 1️⃣ Authentication Layer ✅
**Status:** WORKING

```
✅ User can authenticate via email/password
✅ Session token generated successfully
✅ User ID: 2a5f4b8b-f31e-4a2a-a82f-2d7b917a555e
✅ JWT token valid for API calls
```

**Evidence:**
- `supabase.auth.signInWithPassword()` succeeded
- Session access_token generated
- No auth errors

---

### 2️⃣ Role Assignment Layer ❌
**Status:** SCHEMA MISMATCH

```
❌ Expected structure: role_assignments table
❌ Actual structure: pilot_users table

Expected columns:
- role_assignments.user_id
- role_assignments.role_type

Actual columns (pilot_users):
- pilot_users.user_id
- pilot_users.role (not role_type)
- pilot_users.org_id (not project-based)
- pilot_users.status = 'active'
```

**Issue:** Code queries `role_assignments` but schema uses `pilot_users`

**Migration File:** `20240506000000_sprint3_operations.sql`
- Creates `pilot_users` table with org-level roles
- No `role_assignments` table definition found

---

### 3️⃣ Broker Profile Linkage ❌
**Status:** COLUMN MISSING

```
❌ Error: column brokers_public.owner_user_id does not exist

Expected columns in brokers_public:
- brokers_public.id (uuid, primary key)
- brokers_public.owner_user_id (uuid, references auth.users) ← MISSING
- brokers_public.organization_id (uuid, references organizations)
- brokers_public.company (text)

Current brokers_public schema appears to have:
- id, company, area, city, status, trust_score, verified_performance_rank, etc.
- But NO owner_user_id column
```

**Issue:** Broker profile not linked to user account

**Root Cause:** Schema migrations may not have created brokers_public correctly, or it was created in a different sprint with different field names

---

### 4️⃣ Linking Function ❌
**Status:** FUNCTION MISSING

```
❌ Error: Could not find the function public.is_linked_broker_user(p_user_id)

Expected function signature:
- is_linked_broker_user(p_user_id uuid) → boolean
- Purpose: Check if user owns a broker profile

Alternative functions checked:
- is_pilot_active(p_user_id uuid) ← EXISTS ✅
  But different logic: checks pilot_users.status = 'active'
```

**Issue:** Function referenced in RLS policies doesn't exist

**Migration File:** Not found in schema
- `is_pilot_active()` exists (Sprint 3)
- `is_linked_broker_user()` not found

---

### 5️⃣ RLS Policy Error ❌
**Status:** POLICY REFERENCES MISSING FUNCTION

```
❌ SELECT policy on leads_public failing:
   Error: permission denied for function has_active_data_loan

Policy attempting to call:
  public.has_active_data_loan(id, auth.uid(), 'call')

Function status: Not found in schema cache
```

**Issue:** RLS policy calls `has_active_data_loan()` which doesn't exist

**Expected:** Function should check if user has valid data loan for lead access

---

### 6️⃣ Edge Function Error ❌
**Status:** FUNCTION RETURNING ERROR

```
❌ broker-upload-lead function returned non-2xx status code

Error Details:
- Status: undefined (likely 400 or 500)
- No response body to debug
- Possible causes:
  1. Function trying to link broker using missing column
  2. Function calling is_linked_broker_user() which doesn't exist
  3. Function RLS policy blocking access

```

**Location:** `supabase/functions/broker-upload-lead/index.ts`

Need to check function code for:
- Is it calling `is_linked_broker_user()`?
- Is it checking `brokers_public.owner_user_id`?
- Is RLS policy allowing the service_role INSERT?

---

### 7️⃣ RLS Policy Enforcement ✅
**Status:** WORKING (Correctly Blocks)

```
✅ Direct INSERT to leads_public is blocked
✅ Error: new row violates row-level security policy for table "leads_public"
✅ This is correct behavior - users should NOT insert directly

Good: INSERT protection is working
Bad: No valid path for authenticated brokers to insert (the Edge Function is broken)
```

---

### 8️⃣ Audit Trail ℹ️
**Status:** NOT FOUND YET

```
ℹ️  No audit events found for test user yet
ℹ️  May appear after triggers execute
ℹ️  Cannot verify without successful lead insert
```

---

## ROOT CAUSE ANALYSIS

### Primary Blocker: Schema Inconsistency

The codebase and schema are **out of sync**:

| Component | Code Expects | Schema Has | Status |
|-----------|--------------|-----------|--------|
| **User Roles** | role_assignments table | pilot_users table | ❌ Mismatch |
| **Broker Linking** | brokers_public.owner_user_id | Column missing | ❌ Missing |
| **Linking Function** | is_linked_broker_user() | Not found | ❌ Missing |
| **Data Loan Check** | has_active_data_loan() | Not found | ❌ Missing |
| **RLS on leads_public** | Calls missing functions | Function errors | ❌ Broken |

### Secondary Blocker: Edge Function

The `broker-upload-lead` function likely contains code that:
1. Calls `is_linked_broker_user()` → fails (function missing)
2. Tries to access `brokers_public.owner_user_id` → fails (column missing)
3. Attempts to validate using role_assignments → fails (table structure different)

---

## REQUIRED FIXES

### Fix #1: Add Missing Column to brokers_public
```sql
ALTER TABLE public.brokers_public
ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id);

CREATE INDEX idx_brokers_public_owner ON public.brokers_public(owner_user_id);
```

### Fix #2: Create is_linked_broker_user() Function
```sql
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
      )
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_linked_broker_user(uuid, uuid) TO authenticated, service_role;
```

### Fix #3: Create has_active_data_loan() Function (if missing)
```sql
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

GRANT EXECUTE ON FUNCTION public.has_active_data_loan(uuid, uuid, text) TO authenticated, service_role;
```

### Fix #4: Update broker-upload-lead Edge Function
File: `supabase/functions/broker-upload-lead/index.ts`

Verify function:
```typescript
// 1. Check authenticated
const user = req.user;
if (!user) return new Response('Unauthorized', { status: 401 });

// 2. Check if user is active pilot
const { data: pilotUser } = await supabase
  .from('pilot_users')
  .select('*')
  .eq('user_id', user.id)
  .eq('status', 'active')
  .single();

if (!pilotUser) return new Response('Pilot not active', { status: 403 });

// 3. Get broker profile linked to user
const { data: broker } = await supabase
  .from('brokers_public')
  .select('*')
  .eq('owner_user_id', user.id)
  .single();

if (!broker) return new Response('No broker profile', { status: 403 });

// 4. Insert lead (with broker_id = broker.id)
// 5. Encrypt phone and insert into leads_sensitive
// 6. Return {lead_id, alias} (NO phone visible)
```

### Fix #5: Create role_assignments Table (if using)
OR update code to use `pilot_users` instead

---

## VERIFICATION CHECKLIST

After applying fixes, test:

- [ ] User authenticates successfully
- [ ] `pilot_users.status = 'active'` for test user
- [ ] `brokers_public.owner_user_id` points to authenticated user
- [ ] `is_linked_broker_user(broker_id, user_id)` returns true
- [ ] `has_active_data_loan()` function exists and grants executed
- [ ] `broker-upload-lead` Edge Function returns 2xx status
- [ ] Lead inserted into `leads_public` without errors
- [ ] Phone stored encrypted in `leads_sensitive`
- [ ] Response contains `lead_id` + `alias` (NO phone)
- [ ] Audit trail records the event

---

## FINAL VERDICT

### 🚫 BLOCKED — ROLE/LINKING/RLS ISSUE FOUND

**Reason:** Multiple schema inconsistencies and missing functions prevent authenticated broker lead upload

**Blockers:**
1. Schema table mismatch (role_assignments vs pilot_users)
2. Missing column (brokers_public.owner_user_id)
3. Missing function (is_linked_broker_user)
4. Missing function (has_active_data_loan - or incorrect permissions)
5. Edge Function failure (likely due to above)

**Impact:** 
- ❌ Cannot proceed with Phase 7 UAT
- ❌ Cannot mark launch-ready
- ❌ Authenticated broker cannot upload leads

**Next Action:**
1. Apply migrations for missing columns and functions
2. Update broker-upload-lead Edge Function to use correct schema
3. Re-run this debug script to verify fixes
4. Only then proceed with full UAT

**Do NOT:**
- Disable RLS (it's correctly blocking)
- Add anonymous INSERT policy
- Mark issues "resolved" without testing authenticated flow
- Deploy without fixing

---

## FILES TO REVIEW

- `supabase/functions/broker-upload-lead/index.ts` — Check function logic
- `supabase/migrations/20240506000000_sprint3_operations.sql` — Role structure
- `supabase/migrations/20260507000200_broker_business_vault_premium.sql` — Broker fields
- Sprint migrations for `has_active_data_loan()` and `is_linked_broker_user()` definitions

---

**Report Generated:** 2026-05-18  
**Script:** scripts/debug-authenticated-broker-rls.mjs  
**Status:** 🚫 DO NOT LAUNCH — FIX REQUIRED  
**Severity:** CRITICAL

---

## RECOMMENDATION

**STOP launch preparations temporarily.**

**Priority 1:** Fix schema inconsistencies (1-2 hours)
- Add missing columns
- Create missing functions
- Update Edge Functions to use correct schema

**Priority 2:** Re-test authenticated broker flow (30 minutes)
- Run debug script again
- Verify all 10 checks pass
- Document fixes in migration

**Priority 3:** Resume Phase 7 UAT (30 minutes)
- Complete authenticated broker lead upload test
- Verify end-to-end flow with encryption + audit
- Mark Phase 7 PASS (not before)

**Timeline:** 2-3 hours to unblock, then proceed to launch

---

**Next Step:** Review and apply Fix #1-5 above, then run debug script again.
