// purge-my-account – „Jetzt endgültig löschen“ auf dem Screen „Konto wiederherstellen“ (Migration 028,
// design-handoff/ACCOUNT_ARCHIVE_PLAN.md §4).
//
// Ablauf: Das angemeldete, archivierte Konto ruft diese Function mit seinem Zugangs-Token auf. Die Function prüft
// das Token, akzeptiert nur ein archiviertes Konto (der eigenen UID), macht es sofort fällig (account_mark_due)
// und ruft account-purge für genau dieses Konto auf. So gibt es nur EINEN Löschweg (inkl. Fotos).
//
// Sicherheit: Die UID stammt nur aus dem geprüften Token, nie aus der Anfrage. Aktive Konten werden abgelehnt.
// Keine Tokens oder E-Mail-Adressen im Log.
//
// Antworten: 200 { purged: true } · 401 Token fehlt/ungültig · 405 nicht POST · 409 Konto nicht archiviert
//            502 Löschlauf hat das Konto nicht gelöscht (nächster Lauf versucht es erneut) · 500 Fehler

import { createClient } from "npm:@supabase/supabase-js@2.58.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
  global: { headers: { "x-edge-function": "purge-my-account" } },
});

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
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

    const { data: archived, error: archivedError } = await admin.rpc("account_is_archived", { p_user: user.id });
    if (archivedError) {
      console.error("purge-my-account: status failed", archivedError.code);
      return json(500, { error: "internal" });
    }
    if (archived !== true) return json(409, { error: "not_archived" });

    const { error: dueError } = await admin.rpc("account_mark_due", { p_user: user.id });
    if (dueError) {
      console.error("purge-my-account: mark due failed", dueError.code);
      return json(500, { error: "internal" });
    }

    const run = await fetch(`${SUPABASE_URL}/functions/v1/account-purge`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
      body: JSON.stringify({ user_id: user.id }),
    });
    const result = await run.json().catch(() => ({}));
    if (!run.ok || result?.purged !== 1) {
      console.error("purge-my-account: purge incomplete", user.id, run.status);
      return json(502, { error: "purge_incomplete" });
    }

    console.log("purge-my-account: purged", user.id);
    return json(200, { purged: true });
  } catch (err) {
    console.error("purge-my-account: unexpected", err instanceof Error ? err.name : "unknown");
    return json(500, { error: "internal" });
  }
});
