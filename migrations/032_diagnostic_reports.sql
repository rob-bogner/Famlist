-- 032_diagnostic_reports.sql
-- Absturz- und Hängerberichte (29.09.2026). Die App sammelt Diagnoseberichte von iOS (MetricKit: Absturz, Hänger,
-- CPU-, Schreib- und Startberichte) und schickt sie hierher. So kommen Berichte auch von Geräten an, die nicht
-- am Mac hängen. Anlass: Watchdog-Abbruch am 29.09. 23:09, der nur auf dem iPhone lag.
--
-- Regeln: Angemeldete Nutzer dürfen NUR eigene Berichte anlegen, nichts lesen, ändern oder löschen. Gelesen wird
-- nur mit Service-Rechten (Supabase-Konsole / MCP). Beim Löschen des Profils verschwinden die Berichte mit.
-- Größe je Bericht höchstens 1 MB (ein Absturzbericht mit Aufrufliste hat typischerweise wenige KB).

create table public.diagnostic_reports (
  id uuid primary key,
  profile_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
  received_at timestamptz not null,
  created_at timestamptz not null default now(),
  app_version text not null check (char_length(app_version) <= 40),
  kinds text[] not null check (cardinality(kinds) between 1 and 5),
  payload jsonb not null check (octet_length(payload::text) <= 1000000)
);

create index diagnostic_reports_profile_created_idx on public.diagnostic_reports (profile_id, created_at desc);

alter table public.diagnostic_reports enable row level security;

revoke all on public.diagnostic_reports from public, anon, authenticated;
grant insert on public.diagnostic_reports to authenticated;

create policy diagnostic_reports_insert on public.diagnostic_reports for insert to authenticated
  with check (profile_id = (select auth.uid()) and (select private.caller_active()));
