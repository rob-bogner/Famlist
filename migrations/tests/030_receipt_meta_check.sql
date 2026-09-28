-- Prüfung von 030_receipt_meta.sql. Verändert nichts: endet mit RAISE EXCEPTION (Rollback), Ergebnis in der Meldung.
-- Erwartet (live 29.09.2026): 1 Leopoldstr. 82 · 2 23 · 3 Milchprodukte 0.25 · 4 null null null · 5 abgelehnt · 6 angenommen 132000 · 7 true
do $$
declare
  a uuid := gen_random_uuid(); la uuid := gen_random_uuid(); r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid();
  res text := ''; t text; n int; ok boolean;
begin
  insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at) values
    ('00000000-0000-0000-0000-000000000000', a, 'authenticated', 'authenticated', 'zz030-' || a || '@example.invalid', now(), now());
  insert into lists (id, owner_id, title, is_default) values (la, a, 'LA', false);

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  -- Bon mit Metadaten und erweiterten Zeilen, wie die neue App ihn sendet
  insert into receipts (id, list_id, created_by, store_name, purchased_at, total, line_count, saved_price_count,
                        photo_paths, bytes, lines, store_address, started_at, ended_at)
  values (r1, la, a, 'EDEKA', date '2026-09-24', 2.49, 1, 1, array[la || '/' || r1 || '/1.jpg'], 1000,
          '[{"raw":"KERRYGOLD BUTTER","item":"Butter","price":2.49,"unit_price":2.49,"quantity":1,"saved":true,
             "category":"Milchprodukte","units":0.25,"measure":"kg","item_id":"b1"}]'::jsonb,
          'Leopoldstr. 82', timestamptz '2026-09-24 17:42:00+02', timestamptz '2026-09-24 18:05:00+02');
  select store_address, extract(epoch from ended_at - started_at)::int / 60 into t, n from receipts where id = r1;
  res := res || '1 ' || t || '; 2 ' || n || '; ';
  select (lines->0->>'category') || ' ' || (lines->0->>'units') into t from receipts where id = r1;
  res := res || '3 ' || t || '; ';
  -- Ältere App ohne die neuen Spalten: alles null
  insert into receipts (id, list_id, created_by, store_name, purchased_at, photo_paths)
  values (r2, la, a, 'REWE', current_date, array[la || '/' || r2 || '/1.jpg']);
  select coalesce(store_address, 'null') || ' ' || coalesce(started_at::text, 'null') || ' ' || coalesce(ended_at::text, 'null')
    into t from receipts where id = r2;
  res := res || '4 ' || t || '; ';
  reset role;
  -- Zu lange Adresse → abgelehnt
  begin
    update receipts set store_address = repeat('x', 201) where id = r2;
    res := res || '5 angenommen; ';
  exception when check_violation then res := res || '5 abgelehnt; ';
  end;
  -- 500 Zeilen mit allen neuen Feldern (langer Bon-Text, Kategorie, UUID) passen noch in die Grenze aus 029
  begin
    update receipts set lines = (
      select jsonb_agg(jsonb_build_object(
        'raw', 'FAIRGLOBE VOLLMILCH-SCHOKOLADE 100G', 'item', 'Fairglobe Vollmilch-Schoko', 'price', 3.49,
        'unit_price', 1.75, 'quantity', 2, 'saved', true, 'category', 'Süßes & Snacks', 'units', 100,
        'measure', 'g', 'item_id', gen_random_uuid()::text))
      from generate_series(1, 500)) where id = r2;
    select octet_length(lines::text) into n from receipts where id = r2;
    res := res || '6 angenommen ' || n || '; ';
  exception when check_violation then res := res || '6 abgelehnt; ';
  end;
  -- Die Zugriffsregel gilt unverändert: Die Person sieht ihren Bon mit den neuen Spalten
  set local role authenticated;
  select exists(select 1 from receipts where id = r1 and store_address is not null) into ok;
  res := res || '7 ' || ok;
  reset role;
  raise exception 'ERGEBNIS %', res;
end $$;
