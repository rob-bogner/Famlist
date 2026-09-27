// account-purge – löscht fällige archivierte Konten endgültig, inklusive Fotos (Migration 028,
// design-handoff/ACCOUNT_ARCHIVE_PLAN.md §4).
//
// Ablauf je Konto: Pfade holen (account_storage_paths) → Dateien per Storage-API löschen (Blöcke zu 1000) →
// erneut prüfen → erst wenn keine Datei mehr da ist: account_purge_rows (löscht alle Zeilen und das Konto).
// Bleibt eine Datei übrig, bleibt das Konto stehen und der nächste Lauf versucht es erneut.
//
// Aufrufer: pg_cron (täglich 03:30, ohne Body), admin_delete_user(…, 'purge') und purge-my-account (mit user_id).
// Sicherheit: Die Function löscht nur Konten, deren Frist abgelaufen ist (account_purge_due). Ein Aufruf kann also
// nichts auslösen, was nicht ohnehin fällig wäre; deshalb genügt der öffentliche Anon-Schlüssel (verify_jwt).
// Keine E-Mail-Adressen oder Pfade im Log, nur Konto-IDs und Zahlen.
//
// Antworten: 200 { purged, files, skipped } · 405 nicht POST · 500 Fehler

import { createClient } from "npm:@supabase/supabase-js@2.58.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BATCH = 1000;

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
  global: { headers: { "x-edge-function": "account-purge" } },
});

type StoragePath = { bucket: string; name: string };

function json(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

async function storagePaths(userId: string): Promise<StoragePath[]> {
  const { data, error } = await admin.rpc("account_storage_paths", { p_user: userId });
  if (error) throw new Error(`paths:${error.code}`);
  return (data ?? []) as StoragePath[];
}

async function removeFiles(paths: StoragePath[]): Promise<number> {
  const byBucket = new Map<string, string[]>();
  for (const p of paths) byBucket.set(p.bucket, [...(byBucket.get(p.bucket) ?? []), p.name]);
  let removed = 0;
  for (const [bucket, names] of byBucket) {
    for (let i = 0; i < names.length; i += BATCH) {
      const { data, error } = await admin.storage.from(bucket).remove(names.slice(i, i + BATCH));
      if (error) throw new Error(`remove:${bucket}`);
      removed += data?.length ?? 0;
    }
  }
  return removed;
}

async function purgeAccount(userId: string): Promise<{ purged: boolean; files: number }> {
  const files = await removeFiles(await storagePaths(userId));
  if ((await storagePaths(userId)).length > 0) return { purged: false, files };
  const { data, error } = await admin.rpc("account_purge_rows", { p_user: userId });
  if (error) throw new Error(`rows:${error.code}`);
  return { purged: data === true, files };
}

async function requestedUser(req: Request): Promise<string | null> {
  try {
    const body = await req.json();
    return typeof body?.user_id === "string" ? body.user_id : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== "POST") return json(405, { error: "method_not_allowed" });

    const only = await requestedUser(req);
    const { data: due, error } = await admin.rpc("account_purge_due", { p_limit: 50 });
    if (error) {
      console.error("account-purge: due failed", error.code);
      return json(500, { error: "internal" });
    }
    const users = ((due ?? []) as string[]).filter((id) => only === null || id === only);

    let purged = 0, files = 0, skipped = 0;
    for (const userId of users) {
      try {
        const result = await purgeAccount(userId);
        files += result.files;
        if (result.purged) purged += 1; else skipped += 1;
        console.log("account-purge: account", userId, result.purged ? "purged" : "kept", "files", result.files);
      } catch (err) {
        skipped += 1;
        console.error("account-purge: account failed", userId, err instanceof Error ? err.message : "unknown");
      }
    }

    console.log("account-purge: run", { due: users.length, purged, files, skipped });
    return json(200, { purged, files, skipped });
  } catch (err) {
    console.error("account-purge: unexpected", err instanceof Error ? err.name : "unknown");
    return json(500, { error: "internal" });
  }
});
