-- Prüfung von 029_receipt_lines.sql. Verändert nichts: endet mit RAISE EXCEPTION (Rollback), Ergebnis in der Meldung.
-- Erwartet (Stand 28.09.2026): 1 2 · 2 KERRYGOLD BUTTER · 3 [] · 4 abgelehnt · 5 abgelehnt · 6 true
do $$
declare
  a uuid := gen_random_uuid(); la uuid := gen_random_uuid(); r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid();
  res text := ''; n int; t text; ok boolean;
begin
  insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at) values
    ('00000000-0000-0000-0000-000000000000', a, 'authenticated', 'authenticated', 'zz029-' || a || '@example.invalid', now(), now());
  insert into lists (id, owner_id, title, is_default) values (la, a, 'LA', false);

  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  -- Bon mit zwei Positionen, wie die App ihn sendet
  insert into receipts (id, list_id, created_by, store_name, purchased_at, total, line_count, saved_price_count, photo_paths, bytes, lines)
  values (r1, la, a, 'EDEKA', current_date, 3.88, 2, 1, array[la || '/' || r1 || '/1.jpg'], 1000,
          '[{"raw":"KERRYGOLD BUTTER","item":"Butter","price":2.49,"unit_price":2.49,"quantity":1,"saved":true},
            {"raw":"TUETE","item":null,"price":1.39,"unit_price":1.39,"quantity":1,"saved":false}]'::jsonb);
  select jsonb_array_length(lines), lines->0->>'raw' into n, t from receipts where id = r1;
  res := res || '1 ' || n || '; 2 ' || t || '; ';
  -- Ältere App ohne Spalte: Standardwert
  insert into receipts (id, list_id, created_by, store_name, purchased_at, photo_paths)
  values (r2, la, a, 'REWE', current_date, array[la || '/' || r2 || '/1.jpg']);
  select lines::text into t from receipts where id = r2; res := res || '3 ' || t || '; ';
  -- Kein Array / zu viele Zeilen → abgelehnt (als postgres, sonst verhindert schon RLS das Update)
  reset role;
  begin
    update receipts set lines = '{"raw":"x"}'::jsonb where id = r2;
    res := res || '4 angenommen; ';
  exception when check_violation then res := res || '4 abgelehnt; ';
  end;
  begin
    update receipts set lines = (select jsonb_agg(jsonb_build_object('raw', g)) from generate_series(1, 501) g) where id = r2;
    res := res || '5 angenommen; ';
  exception when check_violation then res := res || '5 abgelehnt; ';
  end;
  -- Preis mit Verweis auf den Bon
  set local role authenticated;
  insert into price_points (profile_id, item_key, item_name, store_name, purchased_at, price, receipt_id)
  values (a, 'butter', 'Butter', 'EDEKA', current_date, 2.49, r1);
  select exists(select 1 from price_points where receipt_id = r1) into ok;
  res := res || '6 ' || ok;
  reset role;
  raise exception 'ERGEBNIS %', res;
end $$;
