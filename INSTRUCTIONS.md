# COPY THIS EXACT SQL CODE

## Instructions

1. **Open Supabase Dashboard:**
   https://app.supabase.com/project/gblvnjilpcxhygvzikwe

2. **Click: SQL Editor** (left sidebar)

3. **Click: New Query**

4. **COPY everything below** (from START COPY to END COPY)

5. **PASTE into Supabase SQL Editor**

6. **Click: RUN** (blue button)

7. **Wait for:** Success message

---

## START COPY ↓↓↓

ALTER TABLE public.brokers_public ADD COLUMN IF NOT EXISTS owner_user_id uuid REFERENCES auth.users(id), ADD COLUMN IF NOT EXISTS organization_id uuid REFERENCES public.organizations(id);

CREATE INDEX IF NOT EXISTS idx_brokers_public_owner_user_id ON public.brokers_public(owner_user_id);

CREATE INDEX IF NOT EXISTS idx_brokers_public_organization_id ON public.brokers_public(organization_id);

CREATE OR REPLACE FUNCTION public.is_linked_broker_user(p_broker_id uuid, p_user_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT EXISTS (SELECT 1 FROM public.brokers_public bp WHERE bp.id = p_broker_id AND bp.owner_user_id = p_user_id AND EXISTS (SELECT 1 FROM public.pilot_users pu WHERE pu.user_id = p_user_id AND pu.status = 'active' AND pu.role IN ('broker', 'broker_owner'))) $$;

GRANT EXECUTE ON FUNCTION public.is_linked_broker_user(uuid, uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.is_linked_broker_user(p_user_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT EXISTS (SELECT 1 FROM public.brokers_public bp WHERE bp.owner_user_id = p_user_id AND EXISTS (SELECT 1 FROM public.pilot_users pu WHERE pu.user_id = p_user_id AND pu.status = 'active' AND pu.role IN ('broker', 'broker_owner'))) $$;

GRANT EXECUTE ON FUNCTION public.is_linked_broker_user(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.has_active_data_loan(p_lead_id uuid, p_user_id uuid, p_purpose text) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT EXISTS (SELECT 1 FROM public.data_loans dl WHERE dl.lead_id = p_lead_id AND dl.granted_to_user_id = p_user_id AND dl.purpose = p_purpose AND dl.status = 'active' AND dl.starts_at <= now() AND dl.expires_at > now() AND dl.revoked_at IS NULL) $$;

GRANT EXECUTE ON FUNCTION public.has_active_data_loan(uuid, uuid, text) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.broker_can_insert_lead(p_user_id uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT EXISTS (SELECT 1 FROM public.pilot_users pu WHERE pu.user_id = p_user_id AND pu.status = 'active' AND pu.role IN ('broker', 'broker_owner')) $$;

GRANT EXECUTE ON FUNCTION public.broker_can_insert_lead(uuid) TO authenticated, service_role;

DROP POLICY IF EXISTS leads_public_broker_insert ON public.leads_public;

CREATE POLICY leads_public_broker_insert ON public.leads_public FOR INSERT TO authenticated WITH CHECK (public.broker_can_insert_lead(auth.uid()) AND broker_id = (SELECT bp.id FROM public.brokers_public bp WHERE bp.owner_user_id = auth.uid() LIMIT 1));

CREATE OR REPLACE FUNCTION public.get_user_broker_id(p_user_id uuid) RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$ SELECT id FROM public.brokers_public WHERE owner_user_id = p_user_id AND EXISTS (SELECT 1 FROM public.pilot_users pu WHERE pu.user_id = p_user_id AND pu.status = 'active') LIMIT 1 $$;

GRANT EXECUTE ON FUNCTION public.get_user_broker_id(uuid) TO authenticated, service_role;

## END COPY ↑↑↑

---

## After Running

1. Should see: ✅ Success messages (no red errors)
2. Wait 30 seconds
3. Then run: `node scripts/debug-authenticated-broker-rls.mjs`
4. Should see: VERDICT: AUTHENTICATED BROKER LEAD UPLOAD PASS

---

## If Error

**"Column already exists"** → Normal, safe to continue
**"Function already exists"** → Normal, safe to continue
**Red error at end** → Wait 30 seconds, try again

---

## Time: 2 minutes
