-- Prüfung der Zugriffsregeln aus 021_receipts_archive.sql (Kassenzettel-Archiv).
-- Ausführen im SQL-Editor oder per MCP execute_sql. Verändert nichts: Der Block endet immer mit
-- RAISE EXCEPTION, dadurch wird alles zurückgerollt (auch das vorübergehende Mitglied).
-- Die Meldung „ERGEBNIS …“ enthält die Ergebnisse. Erwartet (Stand 26.09.2026):
--   1 OK · 2 → 1 · 3 verweigert · 4 verweigert · 5 OK · 6 → 0 · 7 false · 8 true · 9 false · 10 true
--   11 true · 12 → 1 · 13 → 0 · 14 verweigert · 15 → 0 · 16 false · 17 false · 18 true · 19 → 1
--   20 → 0 Zeilen · 21 verweigert
-- Rollen: O = Besitzer einer Liste L, M = vorübergehend Mitglied von L, X = ohne Zugriff auf L.
do $$
declare
  l uuid; o uuid; m uuid; x uuid;
  r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid(); r3 uuid := gen_random_uuid();
  res text := ''; n int;
begin
  select id, owner_id into l, o from lists order by created_at limit 1;
  select p.id into m from profiles p
    where p.id <> o and not exists (select 1 from list_members lm where lm.list_id = l and lm.profile_id = p.id)
    order by p.created_at limit 1;
  select p.id into x from profiles p
    where p.id not in (o, m) and not exists (select 1 from list_members lm where lm.list_id = l and lm.profile_id = p.id)
    order by p.created_at limit 1;
  if l is null or m is null or x is null then raise exception 'setup: zu wenige Profile/Listen'; end if;
  insert into list_members(list_id, profile_id) values (l, m);

  perform set_config('request.jwt.claims', json_build_object('sub',o,'role','authenticated')::text, true);
  set local role authenticated;
  begin insert into receipts(id,list_id,created_by,purchased_at,photo_paths) values (r1,l,o,current_date,array[l||'/'||r1||'/1.jpg']); res:=res||'1 O insert: OK; ';
  exception when others then res:=res||'1 O insert: FAIL '||sqlerrm||'; '; end;

  perform set_config('request.jwt.claims', json_build_object('sub',m,'role','authenticated')::text, true);
  select count(*) into n from receipts where id=r1; res:=res||'2 M sieht r1: '||n||'; ';
  begin insert into receipts(id,list_id,created_by,purchased_at,photo_paths) values (r2,l,o,current_date,array[l||'/'||r2||'/1.jpg']); res:=res||'3 M insert als O: ERLAUBT(!); ';
  exception when others then res:=res||'3 M insert als O: verweigert; '; end;
  begin insert into receipts(id,list_id,created_by,purchased_at,photo_paths) values (r2,l,m,current_date,array[l||'/'||r1||'/1.jpg']); res:=res||'4 M fremder Pfad: ERLAUBT(!); ';
  exception when others then res:=res||'4 M fremder Pfad: verweigert; '; end;
  begin insert into receipts(id,list_id,created_by,purchased_at,photo_paths) values (r2,l,m,current_date,array[l||'/'||r2||'/1.jpg']); res:=res||'5 M insert: OK; ';
  exception when others then res:=res||'5 M insert: FAIL '||sqlerrm||'; '; end;
  delete from receipts where id=r1; get diagnostics n=row_count; res:=res||'6 M löscht r1 von O: '||n||'; ';
  res:=res||'7 M Foto-Upload r1 erlaubt: '||(not private.receipt_row_exists(l||'/'||r1||'/1.jpg') and private.has_list_access(public.storage_folder_uuid(l||'/'||r1||'/1.jpg')))||'; ';
  res:=res||'8 M Foto-Upload neu erlaubt: '||(not private.receipt_row_exists(l||'/'||r3||'/1.jpg') and private.has_list_access(public.storage_folder_uuid(l||'/'||r3||'/1.jpg')))||'; ';
  res:=res||'9 M darf Foto r1 löschen: '||private.can_delete_receipt_file(l||'/'||r1||'/1.jpg')||'; ';
  res:=res||'10 M darf Foto r2 löschen: '||private.can_delete_receipt_file(l||'/'||r2||'/1.jpg')||'; ';
  res:=res||'11 M darf verwaistes Foto löschen: '||private.can_delete_receipt_file(l||'/'||r3||'/1.jpg')||'; ';
  select count(*) into n from profiles where id=o; res:=res||'12 M liest Profil O: '||n||'; ';

  perform set_config('request.jwt.claims', json_build_object('sub',x,'role','authenticated')::text, true);
  select count(*) into n from receipts where list_id=l; res:=res||'13 X sieht Bons: '||n||'; ';
  begin insert into receipts(id,list_id,created_by,purchased_at,photo_paths) values (r3,l,x,current_date,array[l||'/'||r3||'/1.jpg']); res:=res||'14 X insert: ERLAUBT(!); ';
  exception when others then res:=res||'14 X insert: verweigert; '; end;
  delete from receipts where list_id=l; get diagnostics n=row_count; res:=res||'15 X löscht: '||n||'; ';
  res:=res||'16 X Foto lesen: '||private.has_list_access(public.storage_folder_uuid(l||'/'||r1||'/1.jpg'))||'; ';
  res:=res||'17 X verwaistes Foto löschen: '||private.can_delete_receipt_file(l||'/'||r3||'/1.jpg')||'; ';

  perform set_config('request.jwt.claims', json_build_object('sub',o,'role','authenticated')::text, true);
  res:=res||'18 O darf Foto r2 löschen: '||private.can_delete_receipt_file(l||'/'||r2||'/1.jpg')||'; ';
  delete from receipts where id=r2; get diagnostics n=row_count; res:=res||'19 O löscht r2 von M: '||n||'; ';
  begin update receipts set total=1 where id=r1; get diagnostics n=row_count; res:=res||'20 O update: '||n||' Zeilen; ';
  exception when others then res:=res||'20 O update: verweigert; '; end;

  reset role; set local role anon;
  begin select count(*) into n from receipts; res:=res||'21 anon liest: '||n||'; ';
  exception when others then res:=res||'21 anon: verweigert; '; end;
  reset role;
  raise exception 'ERGEBNIS (zurückgerollt): %', res;
end $$;
