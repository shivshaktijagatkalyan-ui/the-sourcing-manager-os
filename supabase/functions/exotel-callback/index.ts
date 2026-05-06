import { adminClient, safeJson, recordAudit, cleanText } from "../_shared/sprint7.ts";

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

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") return safeJson({ ok: false, reason: "invalid_method" }, 405);

  try {
    const attemptId = new URL(req.url).searchParams.get("attempt_id");
    const formData = await req.formData();
    const providerCallId = cleanText(formData.get("CallSid") as string ?? formData.get("Sid") as string);
    const providerStatus = mapStatus(cleanText(formData.get("Status") as string ?? formData.get("CallStatus") as string));
    const durationSeconds = safeDuration(formData.get("Duration")) ?? safeDuration(formData.get("CallDuration"));

    if (!attemptId && !providerCallId) {
      return safeJson({ ok: false, reason: "invalid_input" }, 400);
    }

    const admin = adminClient();
    const update = {
      provider_call_id: providerCallId,
      call_status: providerStatus,
      duration_seconds: durationSeconds,
      updated_at: new Date().toISOString(),
    };

    let query = admin.from("call_attempts").update(update);
    query = attemptId ? query.eq("id", attemptId) : query.eq("provider_call_id", providerCallId);

    const { data: attempt, error: updateError } = await query.select("id, lead_id, caller_id").maybeSingle();

    if (updateError) throw updateError;

    if (attempt) {
      const { data: lead } = await admin
        .from("leads_public")
        .select("organization_id")
        .eq("id", attempt.lead_id)
        .maybeSingle();

      await recordAudit(admin, attempt.caller_id, lead?.organization_id ?? null, attempt.lead_id, "call_callback_received", {
        provider: "exotel",
        call_status: providerStatus,
        duration_recorded: durationSeconds !== null,
      });
    }

    return safeJson({ ok: true }, 200);
  } catch (err) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500);
  }
});
