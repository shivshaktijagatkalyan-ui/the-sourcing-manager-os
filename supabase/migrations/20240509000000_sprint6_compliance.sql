-- Sprint 6: Compliance, Reporting & Enterprise Governance
-- Migration: 20240509000000_sprint6_compliance.sql

-- 1. DPDP Granular Consent Ledger
CREATE TABLE public.consent_ledger (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    lead_id uuid NOT NULL REFERENCES public.leads_public(id) ON DELETE CASCADE,
    consent_type text NOT NULL CHECK (consent_type IN ('call', 'site_visit', 'sms', 'data_sharing')),
    status text NOT NULL CHECK (status IN ('granted', 'denied', 'revoked', 'expired')),
    captured_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz,
    ip_hash text,
    user_agent_hash text,
    evidence_metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_consent_ledger_lead_type ON public.consent_ledger (lead_id, consent_type, status);

-- 2. TRAI/DND Compliance Reporting View
-- Tracks check attempts vs actual calls
CREATE OR REPLACE VIEW public.dnd_compliance_report
AS
SELECT 
    ca.id AS call_id,
    ca.lead_id,
    ca.caller_id,
    ca.call_status,
    lp.dnd_status AS verified_dnd_status,
    ca.created_at AS call_time,
    lp.consent_status AS general_consent
FROM public.call_attempts ca
JOIN public.leads_public lp ON ca.lead_id = lp.id;

-- 3. RERA Project Registry Hardening
ALTER TABLE public.projects 
    ADD COLUMN IF NOT EXISTS rera_verified boolean DEFAULT false,
    ADD COLUMN IF NOT EXISTS rera_last_checked_at timestamptz;

-- 4. Payout Statements (Compliance Grade)
-- A table to cache/version generated statements for audit
CREATE TABLE public.payout_statements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES public.organizations(id),
    broker_id uuid NOT NULL REFERENCES auth.users(id),
    statement_period_start date NOT NULL,
    statement_period_end date NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    payout_count integer NOT NULL,
    status text DEFAULT 'generated' CHECK (status IN ('generated', 'signed', 'void')),
    file_storage_path text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- 5. RLS for Sprint 6
ALTER TABLE public.consent_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payout_statements ENABLE ROW LEVEL SECURITY;

CREATE POLICY consent_ledger_broker_read
ON public.consent_ledger
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.leads_public lp 
        WHERE lp.id = consent_ledger.lead_id 
        AND lp.broker_id = auth.uid()
    )
);

CREATE POLICY payout_statements_broker_read
ON public.payout_statements
FOR SELECT
TO authenticated
USING (broker_id = auth.uid());

CREATE POLICY payout_statements_admin_all
ON public.payout_statements
FOR ALL
TO authenticated
USING (
    public.is_pilot_admin(auth.uid())
    AND public.is_same_active_pilot_org(auth.uid(), organization_id)
);

GRANT SELECT ON public.dnd_compliance_report TO authenticated;
