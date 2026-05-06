-- Sprint 5: Scaling, Automated Payouts & Marketplace Foundation
-- Migration: 20240508000000_sprint5_scaling.sql

-- 1. Automated Payout Ledger
CREATE TABLE public.payout_ledger (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),
    broker_id uuid NOT NULL REFERENCES auth.users(id),
    broker_lock_id uuid NOT NULL REFERENCES public.broker_locks(id),
    amount numeric(12,2) NOT NULL CHECK (amount >= 0),
    currency text NOT NULL DEFAULT 'INR',
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'eligible', 'processing', 'paid', 'rejected')),
    eligibility_date date NOT NULL, -- usually broker_lock.starts_at + 45 days
    payout_date date,
    transaction_ref text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payout_ledger_lock_unique UNIQUE(broker_lock_id)
);

CREATE INDEX idx_payout_ledger_org_status ON public.payout_ledger (organization_id, status);
CREATE INDEX idx_payout_ledger_broker_date ON public.payout_ledger (broker_id, eligibility_date);

-- 2. Marketplace Leaderboard View (Hardened)
-- Only shows anonymized data or public trust scores.
CREATE OR REPLACE VIEW public.broker_leaderboard
WITH (security_invoker = true)
AS
SELECT
    entity_id AS broker_id,
    score AS trust_score,
    (components_json->>'total_verified_visits')::int AS verified_visits,
    (components_json->>'conversion_rate')::numeric(3,2) AS conversion_rate,
    rank() OVER (ORDER BY score DESC, (components_json->>'total_verified_visits')::int DESC) as marketplace_rank
FROM public.trust_scores
WHERE entity_type = 'user'
  AND (components_json->>'is_public')::boolean = true;

-- 3. Lead Routing Configurations
CREATE TABLE public.lead_routing_configs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),
    tier_name text NOT NULL, -- 'elite', 'trusted', 'standard', 'risky'
    min_trust_score numeric(3,2) NOT NULL,
    max_loan_duration_hours integer NOT NULL DEFAULT 4,
    auto_revoke_enabled boolean DEFAULT true,
    priority integer NOT NULL DEFAULT 10,
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE(organization_id, tier_name)
);

-- 4. RLS for Sprint 5
ALTER TABLE public.payout_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lead_routing_configs ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.payout_ledger FROM anon, authenticated, public;
GRANT SELECT ON public.payout_ledger TO authenticated;

CREATE POLICY payout_ledger_self_read
ON public.payout_ledger
FOR SELECT
TO authenticated
USING (broker_id = auth.uid());

CREATE POLICY payout_ledger_admin_read
ON public.payout_ledger
FOR SELECT
TO authenticated
USING (
  public.is_pilot_admin(auth.uid())
  AND public.is_same_active_pilot_org(auth.uid(), organization_id)
);

CREATE POLICY lead_routing_configs_admin_all
ON public.lead_routing_configs
FOR ALL
TO authenticated
USING (
  public.is_pilot_admin(auth.uid())
  AND public.is_same_active_pilot_org(auth.uid(), organization_id)
);

GRANT SELECT ON public.broker_leaderboard TO authenticated;

-- 5. Triggers for Updated At
CREATE TRIGGER set_payout_ledger_updated_at
BEFORE UPDATE ON public.payout_ledger
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_lead_routing_configs_updated_at
BEFORE UPDATE ON public.lead_routing_configs
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
