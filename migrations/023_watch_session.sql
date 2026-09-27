-- 023_watch_session.sql
-- Aufruf-Grenze der Edge Function watch-session (26.09.2026, design-handoff/WATCH_PLAN.md §4)
--
-- watch-session erzeugt mit dem Service-Schlüssel einen einmaligen Anmelde-Code für die Apple Watch.
-- Je Konto ist höchstens 1 Aufruf je 10 s erlaubt. Edge Functions behalten zwischen Aufrufen keinen
-- verlässlichen Zustand (mehrere Instanzen), deshalb steht der letzte Zeitpunkt hier in der Datenbank.
--
-- Nur die Edge Function (Rolle service_role) darf watch_session_claim aufrufen; die App nicht.
-- Konto löschen: Die Zeile verschwindet mit dem Konto (on delete cascade).

create table if not exists private.watch_session_requests (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  last_requested_at timestamptz not null
);

alter table private.watch_session_requests enable row level security;   -- keine Policies: nur über die Funktion
revoke all on private.watch_session_requests from public, anon, authenticated;

-- true = Aufruf erlaubt (Zeitpunkt gemerkt), false = letzter Aufruf liegt weniger als 10 s zurück.
-- Atomar: Zwei gleichzeitige Aufrufe desselben Kontos können nicht beide true erhalten.
create or replace function public.watch_session_claim(p_user uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ok boolean;
begin
  if p_user is null then
    return false;
  end if;
  insert into private.watch_session_requests as r (user_id, last_requested_at)
  values (p_user, now())
  on conflict (user_id) do update
     set last_requested_at = now()
   where r.last_requested_at <= now() - interval '10 seconds'
  returning true into v_ok;
  return coalesce(v_ok, false);
end;
$$;

revoke all on function public.watch_session_claim(uuid) from public, anon, authenticated;
grant execute on function public.watch_session_claim(uuid) to service_role;
