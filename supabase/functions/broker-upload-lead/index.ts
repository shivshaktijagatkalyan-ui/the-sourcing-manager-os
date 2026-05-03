import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function safeJson(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function env(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error("server_error");
  return value;
}

async function currentUser(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;

  const client = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: authHeader } },
  });
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;
  return data.user;
}

function cleanText(value: unknown, max = 120) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > max) return null;
  return trimmed;
}

function cleanOptionalText(value: unknown, max = 120) {
  if (value === undefined || value === null || value === "") return null;
  return cleanText(value, max);
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

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_input" }, 405);

  let oneTimeContact: string | null = null;

  try {
    const user = await currentUser(req);
    if (!user) return safeJson({ ok: false, reason: "access_denied" }, 401);

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
      return safeJson({ ok: false, reason: "invalid_input" }, 400);
    }

    const admin = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
    const { data: ciphertext, error: encryptError } = await admin.rpc("encrypt_lead_contact", {
      p_contact: oneTimeContact,
      p_key: env("PHONE_ENCRYPTION_KEY"),
    });

    oneTimeContact = null;

    if (encryptError || typeof ciphertext !== "string") {
      return safeJson({ ok: false, reason: "server_error" }, 500);
    }

    const { data: lead, error: leadError } = await admin
      .from("leads_public")
      .insert({
        broker_id: user.id,
        alias,
        area,
        city,
        property_name: propertyName,
        budget_min: budgetMin,
        budget_max: budgetMax,
      })
      .select("id, alias")
      .single();

    if (leadError || !lead) {
      return safeJson({ ok: false, reason: "server_error" }, 500);
    }

    const { error: vaultError } = await admin
      .from("leads_sensitive")
      .insert({ lead_id: lead.id, phone_ciphertext: ciphertext });

    if (vaultError) {
      await admin.from("leads_public").delete().eq("id", lead.id);
      return safeJson({ ok: false, reason: "server_error" }, 500);
    }

    await admin.from("audit_events").insert({
      actor_id: user.id,
      lead_id: lead.id,
      event_type: "lead_uploaded",
      event_context: { alias },
    });

    return safeJson({ ok: true, lead_id: lead.id, alias: lead.alias }, 200);
  } catch {
    return safeJson({ ok: false, reason: "server_error" }, 500);
  } finally {
    oneTimeContact = null;
  }
});
