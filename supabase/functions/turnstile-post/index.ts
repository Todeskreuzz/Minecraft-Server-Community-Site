const allowedOrigins = new Set([
  "https://todeskreuzz.github.io",
  "http://127.0.0.1:8018",
  "http://localhost:8018",
]);

function cors(origin: string | null) {
  const allow = origin && allowedOrigins.has(origin) ? origin : "https://todeskreuzz.github.io";
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
    "Content-Type": "application/json",
  };
}

function json(origin: string | null, status: number, payload: Record<string, unknown>) {
  return new Response(JSON.stringify(payload), { status, headers: cors(origin) });
}

Deno.serve(async (request) => {
  const origin = request.headers.get("Origin");
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(origin) });
  if (request.method !== "POST") return json(origin, 405, { error: "Method" });
  const userAuth = request.headers.get("Authorization") || "";
  if (!userAuth.startsWith("Bearer ")) return json(origin, 401, { error: "Not authorized" });
  const body = await request.json().catch(() => null) as Record<string, string> | null;
  const token = String(body?.captcha_token || "");
  const kind = body?.kind === "reply" ? "reply" : body?.kind === "topic" ? "topic" : "";
  if (!token || !kind) return json(origin, 400, { error: "Captcha required" });
  const base = Deno.env.get("SUPABASE_URL") || "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  if (!base || !serviceKey) return json(origin, 503, { error: "Captcha is not configured" });
  const secretResponse = await fetch(base + "/rest/v1/rpc/get_turnstile_secret", {
    method: "POST",
    headers: { apikey: serviceKey, Authorization: "Bearer " + serviceKey, "Content-Type": "application/json" },
    body: "{}",
  });
  const secretBody = await secretResponse.json().catch(() => null);
  const secret = typeof secretBody === "string" ? secretBody : "";
  if (!secretResponse.ok || !secret) return json(origin, 503, { error: "Captcha is not configured" });
  const verify = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ secret, response: token }),
  });
  const verdict = await verify.json().catch(() => ({ success: false }));
  if (!verdict.success) return json(origin, 400, { error: "Captcha required" });
  const clientKey = request.headers.get("apikey") || "";
  const apikey = clientKey.startsWith("sb_publishable_") ? clientKey : (Deno.env.get("SUPABASE_ANON_KEY") || "");
  const row = kind === "topic"
    ? { title: String(body?.title || "").trim(), body: String(body?.body || "").trim(), category_id: String(body?.category_id || "") }
    : { topic_id: String(body?.topic_id || ""), body: String(body?.body || "").trim() };
  if (kind === "topic" && (row.title.length < 3 || row.title.length > 120 || row.body.length < 1 || row.body.length > 10000)) return json(origin, 400, { error: "Invalid update" });
  if (kind === "reply" && (row.body.length < 1 || row.body.length > 10000 || !/^[0-9a-f-]{36}$/.test(row.topic_id))) return json(origin, 400, { error: "Invalid update" });
  const inserted = await fetch(base + "/rest/v1/" + (kind === "topic" ? "forum_topics" : "forum_replies"), {
    method: "POST",
    headers: { apikey, Authorization: userAuth, "Content-Type": "application/json", Prefer: "return=representation" },
    body: JSON.stringify(row),
  });
  const insertedBody = await inserted.json().catch(() => null);
  if (!inserted.ok) return json(origin, inserted.status, { error: insertedBody?.message || "Slow down" });
  return json(origin, 201, { rows: insertedBody });
});
