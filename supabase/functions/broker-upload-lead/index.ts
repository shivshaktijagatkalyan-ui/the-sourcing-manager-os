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

    // 1. Fetch Pilot Context
    const { data: pilot, error: pilotError } = await admin
      .from('pilot_users')
      .select('org_id, status, organizations(status)')
      .eq('user_id', user.id)
      .maybeSingle()

    if (pilotError || !pilot || pilot.status !== 'active' || pilot.organizations?.status !== 'active') {
      return safeJson({ ok: false, reason: 'access_blocked_operational' }, 403)
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

    const area = cleanOptionalText(body.area);
    const city = cleanOptionalText(body.city);
    const propertyName = cleanOptionalText(body.property_name);
    const budgetMin = cleanAmount(body.budget_min);
    const budgetMax = cleanAmount(body.budget_max);

    if (budgetMin !== null && budgetMax !== null && budgetMin > budgetMax) {
      return safeJson({ ok: false, reason: "invalid_input_budget" }, 400);
    }

    // 3. Secure Encryption
    const { data: ciphertext, error: encryptError } = await admin.rpc("encrypt_lead_contact", {
      p_contact: oneTimeContact,
      p_key: Deno.env.get("PHONE_ENCRYPTION_KEY") ?? "",
    });

    oneTimeContact = null;

    if (encryptError || typeof ciphertext !== "string") {
      throw new Error('encryption_failed')
    }

    // 4. Atomic Insert with Org Scope
    const { data: lead, error: leadError } = await admin
      .from("leads_public")
      .insert({
        organization_id: pilot.org_id,
        broker_id: user.id,
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

    if (leadError || !lead) throw new Error('lead_creation_failed')

    const { error: vaultError } = await admin
      .from("leads_sensitive")
      .insert({ lead_id: lead.id, phone_ciphertext: ciphertext });

    if (vaultError) {
      await admin.from("leads_public").delete().eq("id", lead.id);
      throw new Error('vault_insertion_failed')
    }

    await recordAudit(admin, user.id, pilot.org_id, lead.id, 'lead_uploaded', { alias })

    return safeJson({ ok: true, lead_id: lead.id, alias: lead.alias }, 200);

  } catch (err) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500);
  } finally {
    oneTimeContact = null;
  }
});
