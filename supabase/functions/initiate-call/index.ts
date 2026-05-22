// @ts-ignore: Deno import
import { serve } from "std/http/server.ts";
import { adminClient, currentUser, requirePermission, safeJson, recordAudit, validUuid, hmacSha256 } from "../_shared/sprint7.ts";



const allowedLoanFailures = new Set(["access_denied", "loan_expired", "revoked"]);

function providerConfig() {
  const isMock = Deno.env.get("ENABLE_PROVIDER_MOCK") === "true";
  const config = {
    sid: Deno.env.get("EXOTEL_SID") ?? (isMock ? "mock_sid" : ""),
    apiKey: Deno.env.get("EXOTEL_API_KEY") ?? (isMock ? "mock_api_key" : ""),
    apiToken: Deno.env.get("EXOTEL_API_TOKEN") ?? (isMock ? "mock_api_token" : ""),
    callerId: Deno.env.get("EXOTEL_CALLER_ID") ?? (isMock ? "mock_caller_id" : ""),
    callbackSecret: Deno.env.get("EXOTEL_CALLBACK_SECRET") ?? (isMock ? "mock_callback_secret" : ""),
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? (isMock ? "http://localhost:54321" : ""),
    subdomain: Deno.env.get("EXOTEL_SUBDOMAIN") || "api.in.exotel.com",
  };

  const missing = Object.entries(config)
    .filter(([key, value]) => key !== "subdomain" && !value)
    .map(([key]) => key);

  return missing.length > 0 ? { ok: false as const, missing } : { ok: true as const, config };
}

async function markBlocked(admin: ReturnType<typeof adminClient>, callerId: string, leadId: string, orgId: string, status: string, loanId?: string) {
  await admin.from("call_attempts").insert({
    lead_id: leadId,
    caller_id: callerId,
    data_loan_id: loanId ?? null,
    provider: "exotel",
    call_status: status,
  });

  await recordAudit(admin, callerId, orgId, leadId, "call_blocked", { reason: status });
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } });
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405);

  let destination: string | null = null;
  let bridgeBody: URLSearchParams | null = null;

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
    const allowed = await requirePermission(admin, user.id, 'can_call_leads', pilot.org_id)
    if (!allowed) return safeJson({ ok: false, reason: 'forbidden_permission_required' }, 403)

    const body = await req.json();
    const leadId = validUuid(body.lead_id);
    if (!leadId) return safeJson({ ok: false, reason: "invalid_input" }, 400);

    // 3. Fetch Lead & Loan Context
    const { data: lead, error: leadError } = await admin
      .from("leads_public")
      .select("id, organization_id, consent_status, dnd_status")
      .eq("id", leadId)
      .single();

    if (leadError || !lead || lead.organization_id !== pilot.org_id) {
        return safeJson({ ok: false, reason: "lead_not_found_or_forbidden" }, 404);
    }

    const { data: loans, error: loanError } = await admin
      .from("data_loans")
      .select("id, status, starts_at, expires_at, revoked_at")
      .eq("lead_id", leadId)
      .eq("granted_to_user_id", user.id)
      .eq("purpose", "call")
      .order("created_at", { ascending: false })
      .limit(1);

    if (loanError) throw new Error('loan_fetch_failed')

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
      const safeStatus = loanFailure === "access_denied"
        ? "blocked"
        : (allowedLoanFailures.has(loanFailure) ? loanFailure : "blocked");
      await markBlocked(admin, user.id, leadId, pilot.org_id, safeStatus, loan?.id);

      if (loanFailure === 'revoked' || loanFailure === 'loan_expired') {
        await admin.from('abuse_events').insert({
            actor_id: user.id,
            organization_id: pilot.org_id,
            lead_id: leadId,
            event_type: loanFailure === 'revoked' ? 'revoked_loan_access_attempt' : 'call_after_loan_expiry',
            severity: loanFailure === 'revoked' ? 'high' : 'medium',
            risk_score_delta: loanFailure === 'revoked' ? -0.5 : -0.2,
            evidence_ref: { loan_id: loan?.id, status: loan?.status }
        })
      }

      return safeJson({ ok: false, reason: loanFailure }, 403);
    }

    // After loanFailure guard, loan is guaranteed non-null (loanFailure is empty only when loan is valid)
    const validLoan = loan!;

    if (lead.consent_status !== "granted") {
      await markBlocked(admin, user.id, leadId, pilot.org_id, "consent_required", validLoan.id);
      return safeJson({ ok: false, reason: "consent_required" }, 403);
    }

    if (lead.dnd_status === "blocked") {
      await markBlocked(admin, user.id, leadId, pilot.org_id, "dnd_blocked", validLoan.id);
      return safeJson({ ok: false, reason: "dnd_blocked" }, 403);
    }

    const exotel = providerConfig();
    if (!exotel.ok) {
      await markBlocked(admin, user.id, leadId, pilot.org_id, "config_error", validLoan.id);
      await recordAudit(admin, user.id, pilot.org_id, leadId, "call_provider_config_missing", {
        provider: "exotel",
        missing: exotel.missing,
      });
      return safeJson({ ok: false, reason: "provider_config_missing" }, 503);
    }

    // 4. Fetch Secure PII
    const { data: sensitive, error: sensitiveError } = await admin
      .from("leads_sensitive")
      .select("phone_ciphertext")
      .eq("lead_id", leadId)
      .single();

    if (sensitiveError || !sensitive?.phone_ciphertext) throw new Error('pii_fetch_failed')

    const { data: clearValue, error: decryptError } = await admin.rpc("decrypt_lead_contact_for_edge", {
      p_ciphertext: sensitive.phone_ciphertext,
      p_key: Deno.env.get("PHONE_ENCRYPTION_KEY") ?? "",
    });

    if (decryptError || typeof clearValue !== "string" || !clearValue) {
      throw new Error('decryption_failed')
    }

    destination = clearValue;

    // 5. Provider Bridge
    const { data: attempt, error: attemptError } = await admin
      .from("call_attempts")
      .insert({
        lead_id: leadId,
        caller_id: user.id,
        data_loan_id: validLoan.id,
        provider: "exotel",
        call_status: "connecting",
      })
      .select("id")
      .single();

    if (attemptError || !attempt) throw new Error('call_attempt_insert_failed')

    const token = await hmacSha256(attempt.id, exotel.config.callbackSecret);
    const bridgeEndpoint = `https://${exotel.config.subdomain}/v1/Accounts/${exotel.config.sid}/Calls/connect.json`;
    const callbackUrl = `${exotel.config.supabaseUrl}/functions/v1/exotel-callback?attempt_id=${attempt.id}&callback_token=${token}`;

    bridgeBody = new URLSearchParams();
    bridgeBody.append("From", exotel.config.callerId);
    bridgeBody.append("To", destination);
    bridgeBody.append("CallerId", exotel.config.callerId);
    bridgeBody.append("StatusCallback", callbackUrl);

    if (Deno.env.get("ENABLE_PROVIDER_MOCK") === "true") {
      await admin.from("call_attempts").update({ call_status: "queued" }).eq("id", attempt.id);
      await recordAudit(admin, user.id, pilot.org_id, leadId, "call_simulated_in_uat", {
        provider: "exotel",
        attempt_id: attempt.id,
        simulated: true,
      });
      return safeJson({ ok: true, status: "queued" }, 200);
    }

    const bridgeResponse = await fetch(bridgeEndpoint, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${exotel.config.apiKey}:${exotel.config.apiToken}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: bridgeBody,
    });

    if (!bridgeResponse.ok) {
      const diagnostic: Record<string, any> = { 
        status: bridgeResponse.status, 
        provider: "exotel",
        debug: {
          sidLen: exotel.config.sid?.length,
          sidFirstLast: exotel.config.sid ? `${exotel.config.sid[0]}...${exotel.config.sid[exotel.config.sid.length - 1]}` : "",
          apiKeyLen: exotel.config.apiKey?.length,
          apiKeyFirstLast: exotel.config.apiKey ? `${exotel.config.apiKey[0]}...${exotel.config.apiKey[exotel.config.apiKey.length - 1]}` : "",
          apiTokenLen: exotel.config.apiToken?.length,
          apiTokenFirstLast: exotel.config.apiToken ? `${exotel.config.apiToken[0]}...${exotel.config.apiToken[exotel.config.apiToken.length - 1]}` : "",
          subdomain: exotel.config.subdomain,
          callerId: exotel.config.callerId,
          endpoint: bridgeEndpoint,
        }
      };
      try {
        const errorText = await bridgeResponse.text();
        // Exotel returns XML by default if not specified, but we requested .json
        const errorData = JSON.parse(errorText);
        if (errorData?.RestException) {
          diagnostic.error_code = errorData.RestException.Code;
          diagnostic.message = errorData.RestException.Message;
        }
      } catch {
        diagnostic.error_code = "parse_failed";
      }

      await admin.from("call_attempts").update({ call_status: "provider_failed" }).eq("id", attempt.id);
      await recordAudit(admin, user.id, pilot.org_id, leadId, "call_provider_failed", { diagnostic });
      return safeJson({ ok: false, reason: "provider_failed", diagnostic }, 502);
    }

    await admin.from("call_attempts").update({ call_status: "queued" }).eq("id", attempt.id);
    await recordAudit(admin, user.id, pilot.org_id, leadId, "call_queued", { provider: "exotel", attempt_id: attempt.id });

    return safeJson({ ok: true, status: "queued" }, 200);

  } catch (err) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500);
  } finally {
    destination = null;
    if (bridgeBody) bridgeBody.set("To", "");
    bridgeBody = null;
  }
});
