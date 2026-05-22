import {
  adminClient,
  cleanText,
  hmacSha256,
  recordAudit,
  safeJson,
  timingSafeEqualHex,
  validUuid,
} from "../_shared/sprint7.ts";

const terminalStatuses = new Set(["completed", "failed", "provider_failed", "blocked", "expired", "revoked", "dnd_blocked", "consent_required", "config_error"]);

function safeDuration(value: FormDataEntryValue | null) {
  if (typeof value !== "string" || value.trim() === "") return null;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

function mapStatus(value: string | null) {
  switch ((value ?? "").toLowerCase()) {
    case "completed":
      return "completed";
    case "failed":
    case "busy":
    case "no-answer":
    case "canceled":
      return "failed";
    case "in-progress":
    case "queued":
    case "ringing":
      return "queued";
    default:
      return "queued";
  }
}

function canTransition(currentStatus: string, nextStatus: string) {
  if (terminalStatuses.has(currentStatus)) return false;
  if (currentStatus === "connecting") return ["queued", "completed", "failed"].includes(nextStatus);
  if (currentStatus === "queued") return ["queued", "completed", "failed"].includes(nextStatus);
  return false;
}

function normalizeSignature(value: string | null) {
  return cleanText(value, 240)
    .replace(/^sha256=/i, "")
    .replace(/^v1=/i, "")
    .trim();
}

function parseTimestamp(value: string | null) {
  const raw = cleanText(value, 80);
  if (!raw) return null;
  const numeric = Number(raw);
  if (Number.isFinite(numeric)) {
    return new Date(numeric > 10_000_000_000 ? numeric : numeric * 1000);
  }
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function withinReplayWindow(timestamp: Date, now = new Date()) {
  return Math.abs(now.getTime() - timestamp.getTime()) <= 120_000;
}

function timingSafeEqualString(left: string, right: string) {
  if (!left || !right || left.length !== right.length) return false;
  let diff = 0;
  for (let i = 0; i < left.length; i += 1) {
    diff |= left.charCodeAt(i) ^ right.charCodeAt(i);
  }
  return diff === 0;
}

function hexToBase64(hex: string) {
  const bytes = new Uint8Array(hex.match(/.{1,2}/g)?.map((byte) => Number.parseInt(byte, 16)) ?? []);
  let binary = "";
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });
  return btoa(binary);
}

async function verifyExotelSignature(rawBody: string, timestamp: string, signature: string, hmacToken: string) {
  const supplied = normalizeSignature(signature);
  if (!supplied) return false;

  const canonicalBodies = [
    rawBody,
    `${timestamp}.${rawBody}`,
    `${timestamp}:${rawBody}`,
  ];

  for (const canonicalBody of canonicalBodies) {
    const expectedHex = await hmacSha256(canonicalBody, hmacToken);
    if (/^[0-9a-f]+$/i.test(supplied) && timingSafeEqualHex(supplied, expectedHex)) return true;
    if (timingSafeEqualString(supplied, hexToBase64(expectedHex))) return true;
  }

  return false;
}

function payloadValue(payload: URLSearchParams, ...keys: string[]) {
  for (const key of keys) {
    const value = payload.get(key);
    if (value !== null) return value;
  }
  return null;
}

function parsePayload(rawBody: string, contentType: string | null) {
  if (contentType?.includes("application/json")) {
    try {
      const parsed = JSON.parse(rawBody) as Record<string, unknown>;
      return new URLSearchParams(
        Object.entries(parsed).flatMap(([key, value]) =>
          typeof value === "string" || typeof value === "number" || typeof value === "boolean"
            ? [[key, String(value)]]
            : [],
        ),
      );
    } catch {
      return new URLSearchParams();
    }
  }

  return new URLSearchParams(rawBody);
}

async function auditCallback(
  admin: ReturnType<typeof adminClient>,
  attempt: { lead_id: string; caller_id: string | null },
  eventType: string,
  context: Record<string, unknown>,
) {
  const { data: lead } = await admin
    .from("leads_public")
    .select("organization_id")
    .eq("id", attempt.lead_id)
    .maybeSingle();

  await recordAudit(admin, attempt.caller_id, lead?.organization_id ?? null, attempt.lead_id, eventType, {
    provider: "exotel",
    ...context,
  });
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405);

  try {
    const url = new URL(req.url);
    const attemptId = validUuid(url.searchParams.get("attempt_id"));
    const callbackToken = cleanText(url.searchParams.get("callback_token"), 160);
    const callbackSecret = Deno.env.get("EXOTEL_CALLBACK_SECRET") ?? "";
    const hmacToken = Deno.env.get("EXOTEL_HMAC_TOKEN") ?? "";
    const signature = req.headers.get("x-exotel-signature") ?? req.headers.get("x-exotel-signature-sha256");
    const timestampHeader = req.headers.get("x-exotel-timestamp") ?? req.headers.get("x-exotel-request-timestamp");
    const timestamp = parseTimestamp(timestampHeader);

    if (!attemptId || !hmacToken || !signature || !timestampHeader || !timestamp) {
      return safeJson({ ok: false, reason: "callback_auth_required" }, 401);
    }

    if (!withinReplayWindow(timestamp)) {
      return safeJson({ ok: false, reason: "callback_replay_window_expired" }, 401);
    }

    const rawBody = await req.text();
    const signatureOk = await verifyExotelSignature(rawBody, timestampHeader, signature, hmacToken);
    if (!signatureOk) {
      return safeJson({ ok: false, reason: "callback_signature_invalid" }, 401);
    }

    const admin = adminClient();
    const { data: attempt, error: attemptError } = await admin
      .from("call_attempts")
      .select("id, lead_id, caller_id, data_loan_id, call_status, callback_event_hash")
      .eq("id", attemptId)
      .maybeSingle();

    if (attemptError) throw attemptError;
    if (!attempt) return safeJson({ ok: false, reason: "attempt_not_found" }, 404);

    if (callbackSecret) {
      const expectedToken = await hmacSha256(attemptId, callbackSecret);
      if (!callbackToken || !timingSafeEqualHex(callbackToken, expectedToken)) {
        await auditCallback(admin, attempt, "call_callback_rejected", { reason: "invalid_callback_token" });
        return safeJson({ ok: false, reason: "callback_auth_failed" }, 401);
      }
    }

    const payload = parsePayload(rawBody, req.headers.get("content-type"));
    const providerCallId = cleanText(payloadValue(payload, "CallSid", "Sid", "CallUUID"), 120);
    const providerStatus = mapStatus(cleanText(payloadValue(payload, "Status", "CallStatus"), 80));
    const durationSeconds = safeDuration(payloadValue(payload, "Duration", "CallDuration"));
    const eventHash = await hmacSha256(
      `${attemptId}:${providerCallId}:${providerStatus}:${durationSeconds ?? ""}:${timestampHeader}`,
      hmacToken,
    );

    if (attempt.callback_event_hash === eventHash) {
      await auditCallback(admin, attempt, "call_callback_rejected", { reason: "replay" });
      return safeJson({ ok: false, reason: "callback_replay" }, 409);
    }

    if (!canTransition(attempt.call_status, providerStatus)) {
      await auditCallback(admin, attempt, "call_callback_rejected", {
        reason: "invalid_transition",
        from_status: attempt.call_status,
        to_status: providerStatus,
      });
      return safeJson({ ok: false, reason: "invalid_state_transition" }, 409);
    }

    const { error: updateError } = await admin
      .from("call_attempts")
      .update({
        provider_call_id: providerCallId || null,
        call_status: providerStatus,
        duration_seconds: durationSeconds,
        callback_event_hash: eventHash,
        callback_received_at: new Date().toISOString(),
        callback_failure_reason: null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", attemptId)
      .eq("call_status", attempt.call_status);

    if (updateError) throw updateError;

    if (attempt.data_loan_id && (providerStatus === "completed" || providerStatus === "failed")) {
      const { error: loanError } = await admin
        .from("data_loans")
        .update({
          status: "expired",
          expires_at: new Date().toISOString(),
        })
        .eq("id", attempt.data_loan_id)
        .eq("status", "active");

      if (loanError) throw loanError;
    }

    await auditCallback(admin, attempt, "call_callback_received", {
      call_status: providerStatus,
      duration_recorded: durationSeconds !== null,
      data_loan_closed: Boolean(attempt.data_loan_id && (providerStatus === "completed" || providerStatus === "failed")),
    });

    return safeJson({ ok: true }, 200);
  } catch {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500);
  }
});
