-- Salesforce CRM synchronization adapter.
-- Public tables store external IDs and safe metadata only. Restricted buyer
-- contact values are accepted only by service-role RPC paths and are written
-- to the existing encrypted lead vault.

CREATE TABLE IF NOT EXISTS public.salesforce_sync_map (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id uuid NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
  lead_id uuid NOT NULL REFERENCES public.leads_public(id) ON DELETE CASCADE,
  salesforce_id text NOT NULL,
  sobject_type text NOT NULL,
  sync_direction text NOT NULL DEFAULT 'outbound',
  last_sync_payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  last_sync_status text NOT NULL DEFAULT 'pending',
  last_error_code text,
  last_synced_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT salesforce_sync_map_salesforce_id_not_blank CHECK (btrim(salesforce_id) <> ''),
  CONSTRAINT salesforce_sync_map_sobject_type_check CHECK (sobject_type IN ('Lead', 'Opportunity', 'Task')),
  CONSTRAINT salesforce_sync_map_direction_check CHECK (sync_direction IN ('inbound', 'outbound')),
  CONSTRAINT salesforce_sync_map_status_check CHECK (last_sync_status IN ('pending', 'synced', 'retry', 'failed', 'skipped'))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_salesforce_sync_map_lead_sobject
ON public.salesforce_sync_map(lead_id, sobject_type)
WHERE sobject_type IN ('Lead', 'Opportunity');

CREATE UNIQUE INDEX IF NOT EXISTS idx_salesforce_sync_map_external
ON public.salesforce_sync_map(organization_id, salesforce_id, sobject_type);

CREATE INDEX IF NOT EXISTS idx_salesforce_sync_map_org_status
ON public.salesforce_sync_map(organization_id, last_sync_status, updated_at DESC);

CREATE TABLE IF NOT EXISTS public.salesforce_webhook_idempotency (
  event_id text PRIMARY KEY,
  organization_id uuid REFERENCES public.organizations(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  signature_hash text NOT NULL,
  payload_hash text NOT NULL,
  processed_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT salesforce_webhook_event_id_not_blank CHECK (btrim(event_id) <> ''),
  CONSTRAINT salesforce_webhook_event_type_not_blank CHECK (btrim(event_type) <> ''),
  CONSTRAINT salesforce_webhook_signature_hash_not_blank CHECK (btrim(signature_hash) <> ''),
  CONSTRAINT salesforce_webhook_payload_hash_not_blank CHECK (btrim(payload_hash) <> '')
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_salesforce_webhook_signature_hash
ON public.salesforce_webhook_idempotency(signature_hash);

CREATE INDEX IF NOT EXISTS idx_salesforce_webhook_org_processed
ON public.salesforce_webhook_idempotency(organization_id, processed_at DESC);

DROP TRIGGER IF EXISTS set_salesforce_sync_map_updated_at
ON public.salesforce_sync_map;
CREATE TRIGGER set_salesforce_sync_map_updated_at
BEFORE UPDATE ON public.salesforce_sync_map
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.salesforce_sync_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salesforce_sync_map FORCE ROW LEVEL SECURITY;

ALTER TABLE public.salesforce_webhook_idempotency ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salesforce_webhook_idempotency FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS salesforce_sync_map_no_client_access
ON public.salesforce_sync_map;
CREATE POLICY salesforce_sync_map_no_client_access
ON public.salesforce_sync_map
FOR ALL TO authenticated
USING (false)
WITH CHECK (false);

DROP POLICY IF EXISTS salesforce_webhook_idempotency_no_client_access
ON public.salesforce_webhook_idempotency;
CREATE POLICY salesforce_webhook_idempotency_no_client_access
ON public.salesforce_webhook_idempotency
FOR ALL TO authenticated
USING (false)
WITH CHECK (false);

CREATE OR REPLACE FUNCTION public.ingest_salesforce_lead_secure(
  p_organization_id uuid,
  p_salesforce_lead_id text,
  p_event_id text,
  p_alias text,
  p_area text,
  p_city text,
  p_budget numeric,
  p_restricted_contact text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_owner_user_id uuid;
  v_lead_id uuid;
  v_existing_lead_id uuid;
  v_ciphertext text;
  v_contact_hash text;
  v_encryption_key text;
  v_hash_salt text;
  v_alias text;
  v_area text;
  v_city text;
  v_normalized_contact text;
BEGIN
  IF p_organization_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_organization');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.organizations
    WHERE id = p_organization_id
      AND status = 'active'
  ) THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'organization_not_active');
  END IF;

  IF p_salesforce_lead_id IS NULL OR btrim(p_salesforce_lead_id) = '' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'missing_salesforce_id');
  END IF;

  v_alias := left(nullif(btrim(regexp_replace(coalesce(p_alias, ''), '[[:cntrl:]]', '', 'g')), ''), 120);
  v_area := left(nullif(btrim(regexp_replace(coalesce(p_area, ''), '[[:cntrl:]]', '', 'g')), ''), 120);
  v_city := left(nullif(btrim(regexp_replace(coalesce(p_city, ''), '[[:cntrl:]]', '', 'g')), ''), 120);
  v_normalized_contact := regexp_replace(coalesce(p_restricted_contact, ''), '[[:space:]-]', '', 'g');

  IF v_alias IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'alias_required');
  END IF;

  IF v_normalized_contact !~ '^(\+91|0)?[6-9][0-9]{9}$' THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'invalid_contact');
  END IF;

  SELECT pu.user_id
  INTO v_owner_user_id
  FROM public.pilot_users pu
  WHERE pu.org_id = p_organization_id
    AND pu.status = 'active'
  ORDER BY
    CASE pu.role
      WHEN 'sourcing_manager' THEN 1
      WHEN 'platform_admin' THEN 2
      WHEN 'developer_admin' THEN 3
      WHEN 'admin' THEN 4
      ELSE 9
    END,
    pu.created_at ASC
  LIMIT 1;

  IF v_owner_user_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'organization_owner_missing');
  END IF;

  BEGIN
    v_encryption_key := public.get_production_vault_secret('PHONE_ENCRYPTION_KEY');
  EXCEPTION WHEN others THEN
    v_encryption_key := current_setting('app.phone_encryption_key', true);
  END;

  BEGIN
    v_hash_salt := public.get_production_vault_secret('PHONE_HASH_SALT');
  EXCEPTION WHEN others THEN
    v_hash_salt := current_setting('app.phone_hash_salt', true);
  END;

  IF v_encryption_key IS NULL OR length(v_encryption_key) < 32 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'secure_config_missing');
  END IF;

  IF v_hash_salt IS NULL OR length(v_hash_salt) < 16 THEN
    RETURN jsonb_build_object('ok', false, 'reason', 'secure_config_missing');
  END IF;

  SELECT ciphertext, phone_hash
  INTO v_ciphertext, v_contact_hash
  FROM public.ingest_lead_contact_secure(v_normalized_contact, v_encryption_key, v_hash_salt);

  SELECT existing_lead_id
  INTO v_existing_lead_id
  FROM public.check_duplicate_lead(v_contact_hash, p_organization_id)
  WHERE is_duplicate = true
  LIMIT 1;

  IF v_existing_lead_id IS NOT NULL THEN
    INSERT INTO public.salesforce_sync_map (
      organization_id,
      lead_id,
      salesforce_id,
      sobject_type,
      sync_direction,
      last_sync_payload,
      last_sync_status,
      last_synced_at
    )
    VALUES (
      p_organization_id,
      v_existing_lead_id,
      btrim(p_salesforce_lead_id),
      'Lead',
      'inbound',
      jsonb_build_object(
        'event_id', p_event_id,
        'salesforce_id', btrim(p_salesforce_lead_id),
        'alias', v_alias,
        'area', v_area,
        'city', v_city,
        'budget', p_budget,
        'duplicate_existing_lead', true
      ),
      'skipped',
      now()
    )
    ON CONFLICT (lead_id, sobject_type) WHERE sobject_type IN ('Lead', 'Opportunity')
    DO UPDATE SET
      salesforce_id = EXCLUDED.salesforce_id,
      lead_id = EXCLUDED.lead_id,
      last_sync_payload = EXCLUDED.last_sync_payload,
      last_sync_status = EXCLUDED.last_sync_status,
      last_synced_at = now();

    INSERT INTO public.audit_events(lead_id, event_type, event_context)
    VALUES (
      v_existing_lead_id,
      'salesforce_inbound_duplicate_skipped',
      jsonb_build_object(
        'organization_id', p_organization_id,
        'event_id', p_event_id,
        'salesforce_id', btrim(p_salesforce_lead_id)
      )
    );

    RETURN jsonb_build_object(
      'ok', true,
      'lead_id', v_existing_lead_id,
      'status', 'duplicate_skipped'
    );
  END IF;

  INSERT INTO public.leads_public (
    organization_id,
    broker_id,
    assigned_manager_id,
    assigned_sourcing_manager_id,
    alias,
    area,
    city,
    budget_min,
    budget_max,
    lead_status,
    consent_status,
    dnd_status
  )
  VALUES (
    p_organization_id,
    v_owner_user_id,
    v_owner_user_id,
    v_owner_user_id,
    v_alias,
    v_area,
    v_city,
    CASE WHEN p_budget IS NULL THEN NULL ELSE 0 END,
    p_budget,
    'new',
    'pending',
    'unknown'
  )
  RETURNING id INTO v_lead_id;

  INSERT INTO public.leads_sensitive (
    lead_id,
    phone_ciphertext,
    phone_hash,
    encryption_version
  )
  VALUES (
    v_lead_id,
    v_ciphertext,
    v_contact_hash,
    1
  );

  INSERT INTO public.salesforce_sync_map (
    organization_id,
    lead_id,
    salesforce_id,
    sobject_type,
    sync_direction,
    last_sync_payload,
    last_sync_status,
    last_synced_at
  )
  VALUES (
    p_organization_id,
    v_lead_id,
    btrim(p_salesforce_lead_id),
    'Lead',
    'inbound',
    jsonb_build_object(
      'event_id', p_event_id,
      'salesforce_id', btrim(p_salesforce_lead_id),
      'alias', v_alias,
      'area', v_area,
      'city', v_city,
      'budget', p_budget
    ),
    'synced',
    now()
  )
  ON CONFLICT (lead_id, sobject_type) WHERE sobject_type IN ('Lead', 'Opportunity')
  DO UPDATE SET
    salesforce_id = EXCLUDED.salesforce_id,
    lead_id = EXCLUDED.lead_id,
    last_sync_payload = EXCLUDED.last_sync_payload,
    last_sync_status = EXCLUDED.last_sync_status,
    last_synced_at = now();

  INSERT INTO public.audit_events(lead_id, event_type, event_context)
  VALUES (
    v_lead_id,
    'salesforce_inbound_lead_ingested',
    jsonb_build_object(
      'organization_id', p_organization_id,
      'event_id', p_event_id,
      'salesforce_id', btrim(p_salesforce_lead_id),
      'source', 'salesforce'
    )
  );

  RETURN jsonb_build_object(
    'ok', true,
    'lead_id', v_lead_id,
    'status', 'created'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.enqueue_salesforce_verified_lead_sync()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task_id uuid;
  v_payload jsonb;
  v_metadata jsonb;
  v_task_key text;
BEGIN
  IF NEW.organization_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.lead_status = 'visit_verified'
     AND coalesce(NEW.brokerage_status, '') = 'locked'
     AND (
       TG_OP = 'INSERT'
       OR OLD.lead_status IS DISTINCT FROM NEW.lead_status
       OR coalesce(OLD.brokerage_status, '') IS DISTINCT FROM coalesce(NEW.brokerage_status, '')
     ) THEN
    v_task_key := 'salesforce_outbound_sync:lead:' || NEW.id::text;
    v_payload := jsonb_build_object(
      'sync_kind', 'lead_lock',
      'lead_id', NEW.id,
      'organization_id', NEW.organization_id
    );
    v_metadata := jsonb_build_object(
      'source', 'lead_state_trigger',
      'lead_status', NEW.lead_status,
      'brokerage_status', NEW.brokerage_status,
      'retry_count', 0
    );

    INSERT INTO public.enterprise_task_queue (
      task_key,
      task_type,
      payload,
      priority,
      status,
      available_at
    )
    VALUES (
      v_task_key,
      'salesforce_outbound_sync',
      v_payload,
      50,
      'pending',
      now()
    )
    ON CONFLICT (task_key)
    DO UPDATE SET
      payload = EXCLUDED.payload,
      priority = EXCLUDED.priority,
      status = 'pending',
      available_at = now(),
      updated_at = now()
    RETURNING id INTO v_task_id;

    INSERT INTO public.enterprise_task_workflow (
      task_id,
      current_state,
      metadata
    )
    SELECT v_task_id, 'pending', v_metadata
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.enterprise_task_workflow
      WHERE task_id = v_task_id
    );

    INSERT INTO public.enterprise_task_history (
      task_id,
      event_type,
      event_payload,
      agent_name
    )
    VALUES (
      v_task_id,
      'salesforce_outbound_enqueued',
      v_metadata,
      'postgres_trigger'
    );

    INSERT INTO public.audit_events(lead_id, event_type, event_context)
    VALUES (
      NEW.id,
      'salesforce_outbound_sync_enqueued',
      jsonb_build_object(
        'organization_id', NEW.organization_id,
        'task_id', v_task_id,
        'sync_kind', 'lead_lock'
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enqueue_salesforce_call_activity_sync()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_task_id uuid;
  v_org_id uuid;
  v_payload jsonb;
  v_metadata jsonb;
BEGIN
  IF NEW.call_status <> 'completed' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.call_status IS NOT DISTINCT FROM NEW.call_status THEN
    RETURN NEW;
  END IF;

  SELECT organization_id
  INTO v_org_id
  FROM public.leads_public
  WHERE id = NEW.lead_id;

  IF v_org_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_payload := jsonb_build_object(
    'sync_kind', 'activity',
    'interaction_type', 'call_attempt',
    'interaction_id', NEW.id,
    'lead_id', NEW.lead_id,
    'organization_id', v_org_id
  );
  v_metadata := jsonb_build_object(
    'source', 'call_attempt_trigger',
    'retry_count', 0
  );

  INSERT INTO public.enterprise_task_queue (
    task_key,
    task_type,
    payload,
    priority,
    status,
    available_at
  )
  VALUES (
    'salesforce_outbound_sync:call_attempt:' || NEW.id::text,
    'salesforce_outbound_sync',
    v_payload,
    75,
    'pending',
    now()
  )
  ON CONFLICT (task_key)
  DO UPDATE SET
    payload = EXCLUDED.payload,
    status = 'pending',
    available_at = now(),
    updated_at = now()
  RETURNING id INTO v_task_id;

  INSERT INTO public.enterprise_task_workflow (
    task_id,
    current_state,
    metadata
  )
  SELECT v_task_id, 'pending', v_metadata
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.enterprise_task_workflow
    WHERE task_id = v_task_id
  );

  INSERT INTO public.enterprise_task_history (
    task_id,
    event_type,
    event_payload,
    agent_name
  )
  VALUES (
    v_task_id,
    'salesforce_activity_enqueued',
    v_metadata,
    'postgres_trigger'
  );

  INSERT INTO public.audit_events(lead_id, event_type, event_context)
  VALUES (
    NEW.lead_id,
    'salesforce_activity_sync_enqueued',
    jsonb_build_object(
      'organization_id', v_org_id,
      'task_id', v_task_id,
      'interaction_type', 'call_attempt'
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enqueue_salesforce_verified_lead_sync
ON public.leads_public;
CREATE TRIGGER enqueue_salesforce_verified_lead_sync
AFTER INSERT OR UPDATE OF lead_status, brokerage_status
ON public.leads_public
FOR EACH ROW EXECUTE FUNCTION public.enqueue_salesforce_verified_lead_sync();

DROP TRIGGER IF EXISTS enqueue_salesforce_call_activity_sync
ON public.call_attempts;
CREATE TRIGGER enqueue_salesforce_call_activity_sync
AFTER INSERT OR UPDATE OF call_status
ON public.call_attempts
FOR EACH ROW EXECUTE FUNCTION public.enqueue_salesforce_call_activity_sync();

REVOKE ALL ON TABLE public.salesforce_sync_map FROM anon, authenticated, public;
REVOKE ALL ON TABLE public.salesforce_webhook_idempotency FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.ingest_salesforce_lead_secure(uuid, text, text, text, text, text, numeric, text) FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.enqueue_salesforce_verified_lead_sync() FROM anon, authenticated, public;
REVOKE ALL ON FUNCTION public.enqueue_salesforce_call_activity_sync() FROM anon, authenticated, public;

GRANT EXECUTE ON FUNCTION public.ingest_salesforce_lead_secure(uuid, text, text, text, text, text, numeric, text) TO service_role;

COMMENT ON TABLE public.salesforce_sync_map
IS 'PII-free mapping between Sourcing Manager OS leads and Salesforce SObjects.';

COMMENT ON TABLE public.salesforce_webhook_idempotency
IS 'Replay protection ledger for signed Salesforce webhook events.';

COMMENT ON FUNCTION public.ingest_salesforce_lead_secure(uuid, text, text, text, text, text, numeric, text)
IS 'Service-role only Salesforce inbound lead ingestion that encrypts restricted contact data and stores public metadata.';
