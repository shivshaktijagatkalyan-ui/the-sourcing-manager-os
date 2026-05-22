-- SPRINT 8: Duplicate Lead Prevention & Broker Lock Transparency Hardening
-- This migration adds a deterministic hash to leads_sensitive to enable duplicate detection without exposing PII.

-- 1. Add phone_hash column to leads_sensitive
ALTER TABLE public.leads_sensitive ADD COLUMN IF NOT EXISTS phone_hash TEXT;

-- 2. Create index for fast duplicate lookups
CREATE INDEX IF NOT EXISTS idx_leads_sensitive_phone_hash ON public.leads_sensitive (phone_hash);

-- 3. Create a secure ingestion function that returns both ciphertext and hash
-- This reduces round-trips and ensures consistency.
CREATE OR REPLACE FUNCTION public.ingest_lead_contact_secure(
  p_contact TEXT, 
  p_enc_key TEXT,
  p_hash_salt TEXT
)
RETURNS TABLE (
  ciphertext TEXT,
  phone_hash TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_contact IS NULL OR btrim(p_contact) = '' THEN
    RAISE EXCEPTION 'contact_required';
  END IF;

  IF p_enc_key IS NULL OR length(p_enc_key) < 32 THEN
    RAISE EXCEPTION 'encryption_key_invalid';
  END IF;

  RETURN QUERY
  SELECT 
    encode(extensions.pgp_sym_encrypt(p_contact, p_enc_key, 'cipher-algo=aes256'), 'base64') as ciphertext,
    public.safe_hash_text(p_contact, p_hash_salt) as phone_hash;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ingest_lead_contact_secure(TEXT, TEXT, TEXT) TO service_role;

-- 4. Create a check function for duplicate detection
CREATE OR REPLACE FUNCTION public.check_duplicate_lead(
  p_phone_hash TEXT,
  p_org_id UUID
)
RETURNS TABLE (
  is_duplicate BOOLEAN,
  existing_lead_id UUID,
  existing_lead_alias TEXT,
  lock_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    TRUE as is_duplicate,
    lp.id as existing_lead_id,
    lp.alias as existing_lead_alias,
    COALESCE(bl.status, 'none') as lock_status
  FROM public.leads_sensitive ls
  JOIN public.leads_public lp ON lp.id = ls.lead_id
  LEFT JOIN public.broker_locks bl ON bl.lead_id = lp.id AND bl.status = 'active'
  WHERE ls.phone_hash = p_phone_hash
    AND lp.organization_id = p_org_id
  LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_duplicate_lead(TEXT, UUID) TO service_role;
