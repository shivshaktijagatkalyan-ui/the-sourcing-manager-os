-- Hardening reporting views: enforce RLS via security_invoker.
-- This ensures views respect the underlying table policies and do not leak cross-organization metadata.

-- 1. Secure Evidence Timeline View
CREATE OR REPLACE VIEW public.v_evidence_timeline
WITH (security_invoker = true)
AS
SELECT 
    lead_id,
    event_type,
    created_at as timestamp,
    -- Sanitize context: remove any key that looks like a phone number or name
    (
        SELECT jsonb_object_agg(key, value)
        FROM jsonb_each(event_context)
        WHERE key NOT IN ('phone', 'name', 'contact', 'customer_name', 'mobile')
    ) as sanitized_context
FROM public.audit_events;

-- 2. Secure DND Compliance Report View
CREATE OR REPLACE VIEW public.dnd_compliance_report
WITH (security_invoker = true)
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

-- Re-grant access (GRANTs are typically preserved on CREATE OR REPLACE, but good for clarity)
GRANT SELECT ON public.v_evidence_timeline TO authenticated;
GRANT SELECT ON public.dnd_compliance_report TO authenticated;
