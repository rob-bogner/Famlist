-- Prüfung von 031_lists_select_owner.sql. Verändert nichts (RAISE am Ende rollt alles zurück).
-- Erwartet: 1 ok · 2 fremder Nutzer sieht die neue Liste: 0 · 3 anon: 0
do $$
declare
  me uuid; other uuid; got uuid; n int; res text := '';
begin
  select p.id into me from public.profiles p where not private.is_archived(p.id) order by p.created_at limit 1;
  select p.id into other from public.profiles p where p.id <> me and not private.is_archived(p.id) limit 1;
  if me is null or other is null then raise exception 'setup: zwei aktive Profile nötig'; end if;

  perform set_config('request.jwt.claims', json_build_object('sub',me,'role','authenticated')::text, true);
  set local role authenticated;
  insert into public.lists (owner_id, title) values (me, 'Probe') returning id into got;  -- wie PostgREST select=*
  res := res || '1 insert returning: ok; ';

  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub',other,'role','authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from public.lists where id = got;
  res := res || '2 fremder Nutzer sieht Probe: ' || n || '; ';

  reset role;
  perform set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
  set local role anon;
  begin select count(*) into n from public.lists; res := res || '3 anon: ' || n || '; ';
  exception when others then res := res || '3 anon: verweigert; '; end;
  reset role;
  raise exception 'ERGEBNIS (zurückgerollt): %', res;
end $$;
