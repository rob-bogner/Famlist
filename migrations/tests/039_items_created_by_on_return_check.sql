-- Prüfung von items.created_by („hinzugefügt von“) aus 037_items_created_by.sql und
-- 039_items_created_by_on_return.sql.
-- Ausführen im SQL-Editor oder per MCP execute_sql. Verändert nichts: Der Block endet immer mit
-- RAISE EXCEPTION, dadurch wird alles zurückgerollt (auch das vorübergehende Mitglied und der Testartikel).
-- Die Meldung „ERGEBNIS …“ enthält die Ergebnisse. Erwartet (Stand 11.10.2026):
--   1 applied M · 2 M · 3 M · 4 O · 5 O · 6 M, Antwort M · 7 M · 8 stale M · 9 M · 10 M
-- Rollen: O = Besitzer einer Liste L, M = vorübergehend Mitglied von L.
-- Geschrieben wird wie in der App über upsert_items_lww; nur 9 und 10 ändern die Zeile direkt.
do $$
declare
  l uuid; o uuid; m uuid;
  i uuid := gen_random_uuid();
  ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  base jsonb; res text := ''; st text; v text; n int;
begin
  select id, owner_id into l, o from lists order by created_at limit 1;
  select p.id into m from profiles p
  where p.id <> o and not exists (select 1 from list_members lm where lm.list_id = l and lm.profile_id = p.id)
  order by p.created_at limit 1;
  if l is null or m is null then raise exception 'setup: zu wenige Profile/Listen'; end if;
  insert into list_members(list_id, profile_id) values (l, m);
  base := jsonb_build_object('id', i, 'list_id', l, 'name', '__pruefung_039', 'units', 1, 'hlc_node_id', 'chk');
  set local role authenticated;

  -- 1 M legt den Artikel an → M
  perform set_config('request.jwt.claims', json_build_object('sub',m,'role','authenticated')::text, true);
  select u.status into st from upsert_items_lww(jsonb_build_array(base || jsonb_build_object('hlc_timestamp', ms))) u;
  select case created_by when m then 'M' when o then 'O' else 'leer' end into v from items where id = i;
  res := res || '1 M legt an: ' || coalesce(st,'-') || ' ' || coalesce(v,'fehlt') || '; ';

  -- 2 O benennt um (kommt nicht zurück) → bleibt M
  perform set_config('request.jwt.claims', json_build_object('sub',o,'role','authenticated')::text, true);
  perform upsert_items_lww(jsonb_build_array(base || jsonb_build_object('hlc_timestamp', ms+1, 'name', '__pruefung_039 b')));
  select case created_by when m then 'M' when o then 'O' else 'leer' end into v from items where id = i;
  res := res || '2 O ändert: ' || v || '; ';

  -- 3 O hakt ab → bleibt M
  perform upsert_items_lww(jsonb_build_array(base || jsonb_build_object('hlc_timestamp', ms+2, 'isChecked', true)));
  select case created_by when m then 'M' when o then 'O' else 'leer' end into v from items where id = i;
  res := res || '3 O hakt ab: ' || v || '; ';

  -- 4 O macht wieder offen → O
  perform upsert_items_lww(jsonb_build_array(base || jsonb_build_object('hlc_timestamp', ms+3, 'isChecked', false)));
  select case created_by when m then 'M' when o then 'O' else 'leer' end into v from items where id = i;
  res := res || '4 O wieder offen: ' || v || '; ';

  -- 5 M löscht → bleibt O
  perform set_config('request.jwt.claims', json_build_object('sub',m,'role','authenticated')::text, true);
  perform upsert_items_lww(jsonb_build_array(base || jsonb_build_object('hlc_timestamp', ms+4, 'tombstone', true)));
  select case created_by when m then 'M' when o then 'O' else 'leer' end into v from items where id = i;
  res := res || '5 M löscht: ' || v || '; ';

  -- 6 M fügt wieder hinzu → M; die Antwort der Funktion enthält den neuen Wert
  select u.item->>'created_by' into st from upsert_items_lww(jsonb_build_array(base || jsonb_build_object('hlc_timestamp', ms+5))) u;
  select case created_by when m then 'M' when o then 'O' else 'leer' end into v from items where id = i;
  res := res || '6 M fügt wieder hinzu: ' || v || ', Antwort ' || case st when m::text then 'M' when o::text then 'O' else coalesce(st,'leer') end || '; ';

  -- 7 O hakt ab → bleibt M
  perform set_config('request.jwt.claims', json_build_object('sub',o,'role','authenticated')::text, true);
  perform upsert_items_lww(jsonb_build_array(base || jsonb_build_object('hlc_timestamp', ms+6, 'isChecked', true)));
  select case created_by when m then 'M' when o then 'O' else 'leer' end into v from items where id = i;
  res := res || '7 O hakt ab: ' || v || '; ';

  -- 8 O schickt einen veralteten Stand „wieder offen“ → verworfen, bleibt M
  select u.status into st from upsert_items_lww(jsonb_build_array(base || jsonb_build_object('hlc_timestamp', ms+1, 'isChecked', false))) u;
  select case created_by when m then 'M' when o then 'O' else 'leer' end into v from items where id = i;
  res := res || '8 O veraltet wieder offen: ' || coalesce(st,'-') || ' ' || v || '; ';

  -- 9 O schreibt created_by selbst (Artikel bleibt abgehakt) → bleibt M
  update items set created_by = o, hlc_timestamp = ms+7 where id = i;
  select case created_by when m then 'M' when o then 'O' else 'leer' end into v from items where id = i;
  res := res || '9 O fälscht: ' || v || '; ';

  -- 10 ohne Anmeldung (Skript) wieder offen → bleibt M
  reset role;
  perform set_config('request.jwt.claims', '', true);
  update items set "isChecked" = false, hlc_timestamp = ms+8 where id = i;
  select case created_by when m then 'M' when o then 'O' else 'leer' end into v from items where id = i;
  res := res || '10 ohne Anmeldung wieder offen: ' || v || '; ';

  raise exception 'ERGEBNIS %', res;
end $$;
