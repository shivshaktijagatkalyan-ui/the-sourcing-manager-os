// @ts-ignore: Deno import
import { serve } from "std/http/server.ts";
import { safeJson } from "../_shared/sprint7.ts";

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: { "Access-Control-Allow-Origin": "*" } });
  }
  if (req.method !== "POST") {
    return safeJson({ ok: false, reason: "invalid_method" }, 405);
  }

  return safeJson({ ok: false, reason: "ai_voice_callback_disabled" }, 403);
});
