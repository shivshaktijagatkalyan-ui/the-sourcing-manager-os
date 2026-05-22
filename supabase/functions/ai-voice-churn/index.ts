// @ts-ignore: Deno import
import { serve } from "std/http/server.ts";
import { currentUser, safeJson } from "../_shared/sprint7.ts";

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } });
  }
  if (req.method !== "POST") {
    return safeJson({ ok: false, reason: "invalid_method" }, 405);
  }

  try {
    const user = await currentUser(req);
    if (!user) {
      return safeJson({ ok: false, reason: "unauthorized" }, 401);
    }

    return safeJson({ ok: false, reason: "ai_voice_churn_disabled" }, 403);
  } catch (_err) {
    return safeJson({ ok: false, reason: "internal_server_error" }, 500);
  }
});
