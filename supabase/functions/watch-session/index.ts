// watch-session – einmaliger Anmelde-Code für die Apple Watch (design-handoff/WATCH_PLAN.md §2, §4)
//
// Ablauf: Das angemeldete iPhone ruft diese Function mit seinem Zugangs-Token auf. Die Function prüft das
// Token, erzeugt mit dem Service-Schlüssel einen Magic-Link-Code für GENAU dieses Konto (ohne Mail) und
// gibt nur den gehashten Code zurück. Die Uhr löst ihn mit verifyOTP(tokenHash:type: .magiclink) ein und
// erhält eine EIGENE Sitzung. Die Sitzung des iPhones bleibt unberührt.
//
// Sicherheit:
// - Die E-Mail stammt nur aus dem geprüften Token (auth.getUser), nie aus der Anfrage.
// - Der erzeugte Code muss zum selben Konto gehören, sonst wird er nicht herausgegeben.
// - Zurück geht nur hashed_token (nicht action_link, nicht email_otp).
// - Höchstens 1 Aufruf je 10 s und Konto (Migration 023, watch_session_claim).
// - Keine Tokens, Codes oder E-Mail-Adressen im Log.
//
// Antworten: 200 { token_hash, type: "magiclink" } · 401 Token fehlt/ungültig · 403 anonymes Konto
//            405 nicht POST · 422 Konto ohne E-Mail · 429 zu früh (Retry-After: 10) · 500 Fehler

import { createClient } from "npm:@supabase/supabase-js@2.58.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
  global: { headers: { "x-edge-function": "watch-session" } },
});

function json(status: number, body: Record<string, unknown>, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store", ...extra },
  });
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
    if (!jwt) return json(401, { error: "missing_token" });

    const { data: userData, error: userError } = await admin.auth.getUser(jwt);
    const user = userData?.user;
    if (userError || !user) return json(401, { error: "invalid_token" });
    if (user.is_anonymous) return json(403, { error: "anonymous_user" });
    if (!user.email) return json(422, { error: "no_email" });

    const { data: allowed, error: claimError } = await admin.rpc("watch_session_claim", { p_user: user.id });
    if (claimError) {
      console.error("watch-session: claim failed", claimError.code);
      return json(500, { error: "internal" });
    }
    if (allowed !== true) return json(429, { error: "too_many_requests" }, { "Retry-After": "10" });

    const { data: link, error: linkError } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email: user.email,
    });
    const tokenHash = link?.properties?.hashed_token;
    if (linkError || !tokenHash || link?.user?.id !== user.id) {
      console.error("watch-session: generateLink failed", linkError?.status ?? "user_mismatch");
      return json(500, { error: "internal" });
    }

    console.log("watch-session: issued", user.id);
    return json(200, { token_hash: tokenHash, type: "magiclink" });
  } catch (err) {
    console.error("watch-session: unexpected", err instanceof Error ? err.name : "unknown");
    return json(500, { error: "internal" });
  }
});
