import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const allowedLoanFailures = new Set(["access_denied", "loan_expired", "revoked"]);

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

function validUuid(value: unknown) {
  if (typeof value !== "string") return null;
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
    ? value
    : null;
}

async function writeAudit(admin: ReturnType<typeof createClient>, actorId: string, leadId: string, eventType: string, context: Record<string, unknown>) {
  await admin.from("audit_events").insert({
    actor_id: actorId,
    lead_id: leadId,
    event_type: eventType,
    event_context: context,
  });
}

async function markBlocked(admin: ReturnType<typeof createClient>, callerId: string, leadId: string, status: string, loanId?: string) {
  await admin.from("call_attempts").insert({
    lead_id: leadId,
    caller_id: callerId,
    data_loan_id: loanId ?? null,
    provider: "exotel",
    call_status: status,
  });

  await writeAudit(admin, callerId, leadId, "call_blocked", { reason: status });
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return safeJson({ ok: false, reason: "access_denied" }, 405);

  let destination: string | null = null;
  let bridgeBody: URLSearchParams | null = null;

  try {
    const user = await currentUser(req);
    if (!user) return safeJson({ ok: false, reason: "access_denied" }, 401);

    const body = await req.json();
    const keys = Object.keys(body);
    if (keys.length !== 1 || keys[0] !== "lead_id") {
      return safeJson({ ok: false, reason: "invalid_input" }, 400);
    }

    const leadId = validUuid(body.lead_id);
    if (!leadId) return safeJson({ ok: false, reason: "invalid_input" }, 400);

    const admin = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
    const { data: lead, error: leadError } = await admin
      .from("leads_public")
      .select("id, consent_status, dnd_status")
      .eq("id", leadId)
      .single();

    if (leadError || !lead) return safeJson({ ok: false, reason: "access_denied" }, 403);

    const { data: loans, error: loanError } = await admin
      .from("data_loans")
      .select("id, status, starts_at, expires_at, revoked_at, purpose")
      .eq("lead_id", leadId)
      .eq("granted_to_user_id", user.id)
      .eq("purpose", "call")
      .order("created_at", { ascending: false })
      .limit(1);

    if (loanError) return safeJson({ ok: false, reason: "access_denied" }, 403);

    const loan = Array.isArray(loans) ? loans[0] : null;
    const now = Date.now();
    let loanFailure = "access_denied";

    if (loan) {
      if (loan.status === "revoked" || loan.revoked_at) loanFailure = "revoked";
      else if (loan.status !== "active" || new Date(loan.starts_at).getTime() > now || new Date(loan.expires_at).getTime() <= now) {
        loanFailure = "loan_expired";
      } else {
        loanFailure = "";
      }
    }

    if (loanFailure) {
      const safeStatus = allowedLoanFailures.has(loanFailure) ? loanFailure : "access_denied";
      await markBlocked(admin, user.id, leadId, safeStatus, loan?.id);
      return safeJson({ ok: false, reason: safeStatus }, 403);
    }

    if (lead.consent_status !== "granted") {
      await markBlocked(admin, user.id, leadId, "consent_required", loan.id);
      return safeJson({ ok: false, reason: "consent_required" }, 403);
    }

    if (lead.dnd_status === "blocked") {
      await markBlocked(admin, user.id, leadId, "dnd_blocked", loan.id);
      return safeJson({ ok: false, reason: "dnd_blocked" }, 403);
    }

    const { data: sensitive, error: sensitiveError } = await admin
      .from("leads_sensitive")
      .select("phone_ciphertext")
      .eq("lead_id", leadId)
      .single();

    if (sensitiveError || !sensitive?.phone_ciphertext) {
      return safeJson({ ok: false, reason: "access_denied" }, 403);
    }

    const { data: clearValue, error: decryptError } = await admin.rpc("decrypt_lead_contact_for_edge", {
      p_ciphertext: sensitive.phone_ciphertext,
      p_key: env("PHONE_ENCRYPTION_KEY"),
    });

    if (decryptError || typeof clearValue !== "string" || !clearValue) {
      return safeJson({ ok: false, reason: "provider_failed" }, 502);
    }

    destination = clearValue;

    const { data: attempt, error: attemptError } = await admin
      .from("call_attempts")
      .insert({
        lead_id: leadId,
        caller_id: user.id,
        data_loan_id: loan.id,
        provider: "exotel",
        call_status: "connecting",
      })
      .select("id")
      .single();

    if (attemptError || !attempt) return safeJson({ ok: false, reason: "provider_failed" }, 502);

    const sid = env("EXOTEL_SID");
    const apiKey = env("EXOTEL_API_KEY");
    const apiToken = env("EXOTEL_API_TOKEN");
    const subdomain = Deno.env.get("EXOTEL_SUBDOMAIN") || "api.in.exotel.com";
    const bridgeEndpoint = `https://${subdomain}/v1/Accounts/${sid}/Calls/connect.json`;
    const callbackUrl = `${env("SUPABASE_URL")}/functions/v1/exotel-callback?attempt_id=${attempt.id}`;
    const callerId = env("EXOTEL_CALLER_ID");

    bridgeBody = new URLSearchParams();
    bridgeBody.append("From", callerId);
    bridgeBody.append("To", destination);
    bridgeBody.append("CallerId", callerId);
    bridgeBody.append("StatusCallback", callbackUrl);

    const bridgeResponse = await fetch(bridgeEndpoint, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${apiKey}:${apiToken}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: bridgeBody,
    });

    if (!bridgeResponse.ok) {
      await admin.from("call_attempts").update({ call_status: "provider_failed" }).eq("id", attempt.id);
      await writeAudit(admin, user.id, leadId, "call_provider_failed", { provider: "exotel" });
      return safeJson({ ok: false, reason: "provider_failed" }, 502);
    }

    await admin.from("call_attempts").update({ call_status: "queued" }).eq("id", attempt.id);
    await writeAudit(admin, user.id, leadId, "call_queued", { provider: "exotel", attempt_id: attempt.id });

    return safeJson({ ok: true, status: "queued" }, 200);
  } catch {
    return safeJson({ ok: false, reason: "access_denied" }, 403);
  } finally {
    destination = null;
    if (bridgeBody) bridgeBody.set("To", "");
    bridgeBody = null;
  }
});
