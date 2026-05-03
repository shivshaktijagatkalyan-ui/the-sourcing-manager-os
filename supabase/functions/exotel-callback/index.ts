import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function safeJson(body: Record<string, unknown>, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function env(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error("server_error");
  return value;
}

function safeText(value: FormDataEntryValue | null, max = 120) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > max) return null;
  return trimmed;
}

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

serve(async (req) => {
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_input" }, 405);

  try {
    const attemptId = new URL(req.url).searchParams.get("attempt_id");
    const formData = await req.formData();
    const providerCallId = safeText(formData.get("CallSid")) ?? safeText(formData.get("Sid"));
    const providerStatus = mapStatus(safeText(formData.get("Status")) ?? safeText(formData.get("CallStatus")));
    const durationSeconds = safeDuration(formData.get("Duration")) ?? safeDuration(formData.get("CallDuration"));

    if (!attemptId && !providerCallId) {
      return safeJson({ ok: false, reason: "invalid_input" }, 400);
    }

    const admin = createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"));
    const update = {
      provider_call_id: providerCallId,
      call_status: providerStatus,
      duration_seconds: durationSeconds,
      updated_at: new Date().toISOString(),
    };

    let query = admin.from("call_attempts").update(update);
    query = attemptId ? query.eq("id", attemptId) : query.eq("provider_call_id", providerCallId);
    const { data, error } = await query.select("id, lead_id, caller_id").maybeSingle();

    if (error) return safeJson({ ok: false, reason: "server_error" }, 500);

    if (data) {
      await admin.from("audit_events").insert({
        actor_id: data.caller_id,
        lead_id: data.lead_id,
        event_type: "call_callback_received",
        event_context: {
          provider: "exotel",
          call_status: providerStatus,
          duration_recorded: durationSeconds !== null,
        },
      });
    }

    return safeJson({ ok: true }, 200);
  } catch {
    return safeJson({ ok: false, reason: "server_error" }, 500);
  }
});
