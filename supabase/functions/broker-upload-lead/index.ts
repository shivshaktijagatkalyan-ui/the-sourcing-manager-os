import { serve } from "std/http/server.ts";
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, cleanText, validUuid } from "../_shared/sprint7.ts";

function cleanOptionalText(value: unknown, max = 120) {
  if (value === undefined || value === null || value === "") return null;
  return cleanText(value as string, max);
}

function cleanAmount(value: unknown) {
  if (value === undefined || value === null || value === "") return null;
  const amount = Number(value);
  return Number.isFinite(amount) && amount >= 0 ? amount : null;
}

function validUploadContact(value: unknown) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!/^\+?[0-9]{10,15}$/.test(trimmed)) return null;
  return trimmed;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } });
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405);

  let oneTimeContact: string | null = null;

  try {
    const user = await currentUser(req);
    if (!user) return safeJson({ ok: false, reason: "unauthorized" }, 401);

    const admin = adminClient();

    // 1. Fetch Pilot Context (user must be active broker in pilot_users)
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status, role, organizations(status)')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .maybeSingle()

    if (pilotError || !pilot || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
    }

    if (!['broker', 'broker_owner'].includes(pilot.role)) {
      return safeJson({ ok: false, reason: 'forbidden_not_broker' }, 403)
    }

    // 2. Strict Permission Check
    const allowed = await requirePermission(admin, user.id, 'can_upload_leads', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const body = await req.json();
    const alias = cleanText(body.alias);
    oneTimeContact = validUploadContact(body.phone);

    if (!alias || !oneTimeContact) {
      return safeJson({ ok: false, reason: "invalid_input" }, 400);
    }

    // 3. Fetch broker profile linked to authenticated user
    // FIX: Use owner_user_id instead of linked_user_id
    const { data: brokerProfile, error: brokerError } = await admin
      .from("brokers_public")
      .select("id, assigned_sourcing_manager_id")
      .eq("owner_user_id", user.id)
      .eq("organization_id", pilot.org_id)
      .maybeSingle();

    if (brokerError || !brokerProfile?.id) {
      return safeJson({ ok: false, reason: "broker_profile_not_found" }, 403);
    }

    const area = cleanOptionalText(body.area);
    const city = cleanOptionalText(body.city);
    const propertyName = cleanOptionalText(body.property_name);
    const budgetMin = cleanAmount(body.budget_min);
    const budgetMax = cleanAmount(body.budget_max);

    if (budgetMin !== null && budgetMax !== null && budgetMin > budgetMax) {
      return safeJson({ ok: false, reason: "invalid_input_budget" }, 400);
    }

    // 4. Secure Encryption & Ingestion
    const encryptionKey = Deno.env.get("PHONE_ENCRYPTION_KEY") ?? ""
    const hashSalt = Deno.env.get("PHONE_HASH_SALT") || "default_broker_salt_2026"
    if (!encryptionKey) {
      oneTimeContact = null;
      return safeJson({ ok: false, reason: "secure_config_missing" }, 503)
    }

    const { data: ingestion, error: ingestError } = await admin.rpc('ingest_lead_contact_secure', {
      p_contact: oneTimeContact,
      p_enc_key: encryptionKey,
      p_hash_salt: hashSalt
    })

    oneTimeContact = null;

    if (ingestError || !ingestion || ingestion.length === 0) {
      throw new Error('encryption_failed')
    }

    const { ciphertext, phone_hash } = ingestion[0]

    // 5. Check for duplicates in this Org
    const { data: duplicateCheck } = await admin.rpc('check_duplicate_lead', {
      p_phone_hash: phone_hash,
      p_org_id: pilot.org_id
    })

    if (duplicateCheck && duplicateCheck.length > 0 && duplicateCheck[0].is_duplicate) {
      const dup = duplicateCheck[0]
      // Record Attempted Duplicate Abuse Event
      await admin.from('abuse_events').insert({
        organization_id: pilot.org_id,
        actor_id: user.id,
        lead_id: dup.existing_lead_id,
        event_type: 'duplicate_lock_attempt',
        severity: 'medium',
        evidence_ref: {
          attempted_alias: alias,
          existing_alias: dup.existing_lead_alias,
          lock_status: dup.lock_status
        }
      })

      return safeJson({
        ok: false,
        reason: "duplicate_lead_detected",
        alias: dup.existing_lead_alias,
        is_locked: dup.lock_status === 'active'
      }, 409)
    }

    // 6. Atomic Insert with Org Scope
    const { data: lead, error: leadError } = await admin
      .from("leads_public")
      .insert({
        organization_id: pilot.org_id,
        broker_id: brokerProfile.id,
        source_broker_id: brokerProfile.id,
        assigned_sourcing_manager_id: brokerProfile.assigned_sourcing_manager_id,
        assigned_manager_id: brokerProfile.assigned_sourcing_manager_id,
        alias,
        area,
        city,
        property_name: propertyName,
        budget_min: budgetMin,
        budget_max: budgetMax,
        lead_status: 'new'
      })
      .select("id, alias")
      .single();

    if (leadError || !lead) {
      throw new Error('lead_creation_failed');
    }

    const { error: vaultError } = await admin
      .from("leads_sensitive")
      .insert({
        lead_id: lead.id,
        phone_ciphertext: ciphertext,
        phone_hash: phone_hash
      });

    if (vaultError) {
      await admin.from("leads_public").delete().eq("id", lead.id);
      throw new Error('vault_insertion_failed')
    }

    await recordAudit(admin, user.id, pilot.org_id, lead.id, 'lead_uploaded', { alias })

    return safeJson({ ok: true, lead_id: lead.id, alias: lead.alias }, 200);

  } catch (_err: unknown) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500);
  } finally {
    oneTimeContact = null;
  }
});
