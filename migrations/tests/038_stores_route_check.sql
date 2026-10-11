-- Prüfung der Zugriffsregeln und Wächter aus 038_stores_route.sql (Märkte & Einkaufsroute).
-- Ausführen im SQL-Editor oder per MCP execute_sql. Verändert nichts: Der Block endet immer mit
-- RAISE EXCEPTION, dadurch wird alles zurückgerollt (auch das vorübergehende Mitglied).
-- Die Meldung „ERGEBNIS …“ enthält die Ergebnisse. Erwartet (Stand 11.10.2026):
--   1 OK · 2 → 1 · 3 → 1 · 4 → 0 · 5 verweigert · 6 OK · 7 verweigert · 8 → 1 · 9 → 0 · 10 → 3
--   11 → 3 · 12 verweigert · 13 → 0 · 14 verweigert · 15 → 0 · 16 → Markt A · 17 → Markt B
--   18 verweigert · 19 verweigert · 20 → true · 21 verweigert · 22 → 0 · 23 → 0 · 24 verweigert
-- Rollen: O = Besitzer einer Liste L, M = vorübergehend Mitglied von L, X = teilt keine Liste mit O.
-- M und X teilen vor dem Test keine Liste mit O (sonst sähen sie die Märkte von O ohnehin).
do $$
declare
  l uuid; o uuid; m uuid; x uuid;
  s1 uuid := gen_random_uuid(); s2 uuid := gen_random_uuid();
  t1 uuid := gen_random_uuid(); t2 uuid := gen_random_uuid();
  ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  res text := ''; n int; v text; b boolean;
begin
  select id, owner_id into l, o from lists order by created_at limit 1;
  -- Profile ohne gemeinsame Liste mit O
  create temp table _strangers on commit drop as
    with membership as (
      select id as list_id, owner_id as pid from lists
      union
      select list_id, profile_id from list_members
    )
    select p.id, p.created_at from profiles p
    where p.id <> o
      and not exists (select 1 from membership a join membership b using (list_id)
                      where a.pid = o and b.pid = p.id);
  select id into m from _strangers order by created_at limit 1;
  select id into x from _strangers where id <> m order by created_at limit 1;
  if l is null or m is null or x is null then raise exception 'setup: zu wenige Profile/Listen'; end if;
  insert into list_members(list_id, profile_id) values (l, m);

  -- O legt einen Markt an
  perform set_config('request.jwt.claims', json_build_object('sub',o,'role','authenticated')::text, true);
  set local role authenticated;
  begin insert into stores(id,owner_id,name,latitude,longitude,hlc_timestamp,hlc_node_id) values (s1,o,'Markt A',48.1,11.5,ms,'o'); res:=res||'1 O insert Markt: OK; ';
  exception when others then res:=res||'1 O insert Markt: FAIL '||sqlerrm||'; '; end;
  select count(*) into n from stores where id=s1; res:=res||'2 O sieht s1: '||n||'; ';

  -- M teilt L mit O: sieht den Markt, darf ihn nicht ändern, darf Einkäufe schreiben
  perform set_config('request.jwt.claims', json_build_object('sub',m,'role','authenticated')::text, true);
  select count(*) into n from stores where id=s1; res:=res||'3 M sieht s1: '||n||'; ';
  update stores set name='Gekapert', hlc_timestamp=ms+1 where id=s1; get diagnostics n=row_count; res:=res||'4 M ändert s1: '||n||'; ';
  begin insert into stores(id,owner_id,name,latitude,longitude,hlc_timestamp) values (s2,o,'Fremd',48.1,11.5,ms); res:=res||'5 M insert Markt für O: ERLAUBT(!); ';
  exception when others then res:=res||'5 M insert Markt für O: verweigert; '; end;
  begin insert into store_trips(id,store_id,profile_id,categories,started_at,ended_at) values (t1,s1,m,array['Obst','Brot'],now()-interval '30 min',now()-interval '20 min'); res:=res||'6 M insert Einkauf: OK; ';
  exception when others then res:=res||'6 M insert Einkauf: FAIL '||sqlerrm||'; '; end;
  begin insert into store_trips(id,store_id,profile_id,categories,started_at,ended_at) values (t2,s1,o,array['Obst','Brot'],now()-interval '30 min',now()); res:=res||'7 M insert Einkauf als O: ERLAUBT(!); ';
  exception when others then res:=res||'7 M insert Einkauf als O: verweigert; '; end;

  -- O sieht den Einkauf von M, darf ihn nicht ändern
  perform set_config('request.jwt.claims', json_build_object('sub',o,'role','authenticated')::text, true);
  select count(*) into n from store_trips where id=t1; res:=res||'8 O sieht t1: '||n||'; ';
  update store_trips set categories=array['A','B'], ended_at=now() where id=t1; get diagnostics n=row_count; res:=res||'9 O ändert t1 von M: '||n||'; ';

  -- M schreibt seinen Einkauf fort; ein älterer Stand wird verworfen
  perform set_config('request.jwt.claims', json_build_object('sub',m,'role','authenticated')::text, true);
  update store_trips set categories=array['Obst','Brot','Milch'], ended_at=now()-interval '10 min' where id=t1;
  select cardinality(categories) into n from store_trips where id=t1; res:=res||'10 M schreibt fort, Kategorien: '||n||'; ';
  update store_trips set categories=array['Obst','Brot'], ended_at=now()-interval '25 min' where id=t1;
  select cardinality(categories) into n from store_trips where id=t1; res:=res||'11 M älterer Stand, Kategorien: '||n||'; ';
  begin insert into store_trips(id,store_id,profile_id,categories,started_at,ended_at) values (t2,s1,m,array['Obst'],now()-interval '5 min',now()); res:=res||'12 Einkauf mit 1 Kategorie: ERLAUBT(!); ';
  exception when others then res:=res||'12 Einkauf mit 1 Kategorie: verweigert; '; end;

  -- X teilt keine Liste mit O
  perform set_config('request.jwt.claims', json_build_object('sub',x,'role','authenticated')::text, true);
  select count(*) into n from stores where id=s1; res:=res||'13 X sieht s1: '||n||'; ';
  begin insert into store_trips(id,store_id,profile_id,categories,started_at,ended_at) values (t2,s1,x,array['Obst','Brot'],now()-interval '5 min',now()); res:=res||'14 X insert Einkauf: ERLAUBT(!); ';
  exception when others then res:=res||'14 X insert Einkauf: verweigert; '; end;
  select count(*) into n from store_trips where store_id=s1; res:=res||'15 X sieht Einkäufe: '||n||'; ';

  -- Letzter Schreiber gewinnt, feste Spalten, kein DELETE
  perform set_config('request.jwt.claims', json_build_object('sub',o,'role','authenticated')::text, true);
  update stores set name='Veraltet', hlc_timestamp=ms-1000 where id=s1;
  select name into v from stores where id=s1; res:=res||'16 O ältere HLC, Name: '||v||'; ';
  update stores set name='Markt B', hlc_timestamp=ms+1000 where id=s1;
  select name into v from stores where id=s1; res:=res||'17 O neuere HLC, Name: '||v||'; ';
  begin update stores set hlc_timestamp=ms+200000000 where id=s1; res:=res||'18 HLC in der Zukunft: ERLAUBT(!); ';
  exception when others then res:=res||'18 HLC in der Zukunft: verweigert; '; end;
  begin update stores set owner_id=m, hlc_timestamp=ms+2000 where id=s1; res:=res||'19 Besitzer wechseln: ERLAUBT(!); ';
  exception when others then res:=res||'19 Besitzer wechseln: verweigert; '; end;
  update stores set tombstone=true, hlc_timestamp=ms+3000 where id=s1;
  select tombstone into b from stores where id=s1; res:=res||'20 O löscht per tombstone: '||b||'; ';
  begin delete from stores where id=s1; res:=res||'21 O DELETE: ERLAUBT(!); ';
  exception when others then res:=res||'21 O DELETE: verweigert; '; end;

  -- M verlässt die Liste: Markt und Einkäufe von O sind nicht mehr sichtbar
  reset role;
  delete from list_members where list_id=l and profile_id=m;
  perform set_config('request.jwt.claims', json_build_object('sub',m,'role','authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from stores where id=s1; res:=res||'22 M ohne Liste sieht s1: '||n||'; ';
  select count(*) into n from store_trips where id=t1; res:=res||'23 M ohne Liste sieht t1: '||n||'; ';

  reset role; set local role anon;
  begin select count(*) into n from stores; res:=res||'24 anon liest: '||n||'; ';
  exception when others then res:=res||'24 anon: verweigert; '; end;
  reset role;
  raise exception 'ERGEBNIS (zurückgerollt): %', res;
end $$;
