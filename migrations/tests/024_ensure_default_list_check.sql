-- Prüfung von 024_ensure_default_list_rls.sql. Verändert nichts (RAISE am Ende rollt alles zurück).
-- Erwartet: 1 → 1 (bestehende Standardliste) · 2 gleich · 3 → 1 (neu angelegt) · 4 true · 5 → 1 · 6 verweigert
do $$
declare
  u uuid; existing uuid; fresh uuid := gen_random_uuid(); got uuid; n int; res text := '';
begin
  select owner_id, id into u, existing from lists where is_default order by created_at limit 1;
  if u is null then raise exception 'setup: keine Standardliste'; end if;
  perform set_config('request.jwt.claims', json_build_object('sub',u,'role','authenticated')::text, true);
  set local role authenticated;
  select count(*), min(id::text)::uuid into n, got from public.ensure_default_list(gen_random_uuid(), 'X');
  res := res || '1 Zeilen: ' || n || '; 2 gleiche Liste: ' || (got = existing) || '; ';

  reset role;
  update lists set is_default = false where id = existing;          -- Konto ohne Standardliste (zurückgerollt)
  set local role authenticated;
  select count(*), min(id::text)::uuid into n, got from public.ensure_default_list(fresh, 'Neu');
  res := res || '3 Zeilen: ' || n || '; 4 neue ID übernommen: ' || (got = fresh) || '; ';
  select count(*) into n from public.ensure_default_list(gen_random_uuid(), 'Nochmal');
  res := res || '5 zweiter Aufruf: ' || n || '; ';

  reset role; set local role anon;
  perform set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
  begin perform public.ensure_default_list(null, 'x'); res := res || '6 anon: ERLAUBT(!); ';
  exception when others then res := res || '6 anon: verweigert; '; end;
  reset role;
  raise exception 'ERGEBNIS (zurückgerollt): %', res;
end $$;
