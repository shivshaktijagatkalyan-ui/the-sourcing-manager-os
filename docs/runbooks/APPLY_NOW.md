# ✅ READY TO APPLY - SQL READY TO PASTE

## DO THIS NOW (2 MINUTES)

1. **Open Supabase Dashboard**
   - https://app.supabase.com/project/gblvnjilpcxhygvzikwe

2. **SQL Editor**
   - Click "SQL Editor" in left sidebar
   - Click "New Query"

3. **Copy SQL**
   - Read file: `PASTE_THIS_SQL.md`
   - Copy everything in the code block

4. **Paste & Run**
   - Paste into Supabase SQL Editor
   - Click blue RUN button
   - Wait for "Query successful"

5. **Done!**
   - All 5 fixes applied
   - Next: Run debug script

---

## THEN VERIFY (1 MINUTE)

```bash
node scripts/debug-authenticated-broker-rls.mjs
```

Should show:
```
✅ All 10 checks pass
VERDICT: A. AUTHENTICATED BROKER LEAD UPLOAD PASS
```

---

## FILES

- `PASTE_THIS_SQL.md` ← Copy this SQL
- `supabase/migrations/20260518000000_fix_authenticated_broker_rls_CLEAN.sql` ← Clean version
- `supabase/functions/broker-upload-lead/index.ts` ← Already updated

---

## What Gets Fixed

| Issue | Status |
|-------|--------|
| Missing owner_user_id column | ✅ FIXED |
| Missing is_linked_broker_user() | ✅ FIXED |
| Missing has_active_data_loan() | ✅ FIXED |
| Missing INSERT policy | ✅ FIXED |
| Edge Function using wrong column | ✅ FIXED |

---

## Timeline

- **Apply SQL:** 2 minutes
- **Verify:** 1 minute
- **UAT:** 30 minutes
- **Total:** 33 minutes

---

**Start:** Open `PASTE_THIS_SQL.md` and follow instructions
