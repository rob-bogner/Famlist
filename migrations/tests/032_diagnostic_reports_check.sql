-- Prüfung von 032_diagnostic_reports.sql. Verändert nichts (RAISE am Ende rollt alles zurück).
-- Erwartet: 1 eigener Bericht: ok · 2 lesen: verweigert · 3 fremde profile_id: verweigert · 4 anon: verweigert
do $$
declare
  me uuid; other uuid; n int; res text := '';
begin
  select p.id into me from public.profiles p where not private.is_archived(p.id) order by p.created_at limit 1;
  select p.id into other from public.profiles p where p.id <> me limit 1;
  if me is null or other is null then raise exception 'setup: zwei Profile nötig'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub',me,'role','authenticated')::text, true);
  set local role authenticated;
  insert into public.diagnostic_reports (id, received_at, app_version, kinds, payload)
    values (gen_random_uuid(), now(), '1.0 (2)', array['crash'], '{"crashDiagnostics":[]}');
  res := res || '1 eigener Bericht: ok; ';

  begin select count(*) into n from public.diagnostic_reports; res := res || '2 lesen: ERLAUBT(!) ' || n || '; ';
  exception when others then res := res || '2 lesen: verweigert; '; end;

  begin
    insert into public.diagnostic_reports (id, profile_id, received_at, app_version, kinds, payload)
      values (gen_random_uuid(), other, now(), 'x', array['hang'], '{}');
    res := res || '3 fremde profile_id: ERLAUBT(!); ';
  exception when others then res := res || '3 fremde profile_id: verweigert; '; end;

  reset role;
  perform set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
  set local role anon;
  begin
    insert into public.diagnostic_reports (id, received_at, app_version, kinds, payload)
      values (gen_random_uuid(), now(), 'x', array['crash'], '{}');
    res := res || '4 anon: ERLAUBT(!); ';
  exception when others then res := res || '4 anon: verweigert; '; end;
  reset role;
  raise exception 'ERGEBNIS (zurückgerollt): %', res;
end $$;
