-- Prüfung von 022_catalog_usage.sql (RPC catalog_note_use) und 023_watch_session.sql (watch_session_claim).
-- Ausführen im SQL-Editor oder per MCP execute_sql. Verändert nichts: Der Block endet immer mit
-- RAISE EXCEPTION, dadurch wird alles zurückgerollt (auch die Test-Einträge im Artikelstamm).
-- Die Meldung „ERGEBNIS …“ enthält die Ergebnisse. Erwartet (Stand 26.09.2026):
--   1 → 1 · 2 → 2 · 3 true · 4 → 1 · 5 → 3 · 6 true · 7 → 0 · 8 → 0 · 9 → 4 · 10 → 0 · 11 → 0
--   12 verweigert · 13 verweigert · 14 verweigert · 15 true · 16 false · 17 true · 18 verweigert
-- Rollen: A = Konto mit Test-Einträgen „zz-022-milch“/„zz-022-brot“, B = anderes Konto.
do $$
declare
  a uuid; b uuid;
  suffix text := substr(md5(random()::text), 1, 8);
  milch text := 'zz-022-milch-' || suffix;
  brot  text := 'zz-022-brot-'  || suffix;
  res text := ''; n int; c int; t timestamptz; t2 timestamptz; ok boolean;
begin
  select id into a from profiles order by created_at limit 1;
  select id into b from profiles where id <> a order by created_at limit 1;
  if a is null or b is null then raise exception 'setup: zu wenige Profile'; end if;
  insert into item_catalog(owner_public_id, name, measure) values (a::text, initcap(milch), 'l'), (a::text, brot, 'pcs');

  perform set_config('request.jwt.claims', json_build_object('sub',a,'role','authenticated')::text, true);
  set local role authenticated;
  -- 1/2: Name in anderer Schreibweise zählt; derselbe Name zweimal im Aufruf zählt doppelt.
  n := public.catalog_note_use(array[upper(milch), milch], null); res:=res||'1 A zählt Milch: '||n||' Zeile(n); ';
  select use_count, last_used_at into c, t from item_catalog where name_lower = milch;
  res:=res||'2 use_count Milch: '||c||'; ';
  res:=res||'3 last_used_at gesetzt: '||(t is not null and t <= now())||'; ';
  -- 4/5: Zeitpunkt in der Zukunft wird auf now() begrenzt.
  n := public.catalog_note_use(array[milch], now() + interval '2 days'); res:=res||'4 A zählt mit Zukunftszeit: '||n||'; ';
  select use_count, last_used_at into c, t2 from item_catalog where name_lower = milch;
  res:=res||'5 use_count Milch: '||c||'; ';
  res:=res||'6 kein Zeitpunkt in der Zukunft: '||(t2 <= now())||'; ';
  -- 7: älterer Zeitpunkt (offline nachgesendet) zählt, setzt last_used_at aber nicht zurück.
  perform public.catalog_note_use(array[milch], now() - interval '3 days');
  select count(*) into n from item_catalog where name_lower = milch and last_used_at < t2;
  res:=res||'7 last_used_at zurückgesetzt: '||n||'; ';
  -- 8: unbekannter Name → nichts geändert.
  n := public.catalog_note_use(array['zz-022-gibt-es-nicht-' || suffix], null); res:=res||'8 unbekannter Name: '||n||'; ';
  select use_count into c from item_catalog where name_lower = milch; res:=res||'9 use_count Milch: '||c||'; ';

  -- 10/11: B kann A nicht zählen und sieht A's Einträge nicht.
  perform set_config('request.jwt.claims', json_build_object('sub',b,'role','authenticated')::text, true);
  n := public.catalog_note_use(array[milch, brot], null); res:=res||'10 B zählt A: '||n||'; ';
  select count(*) into n from item_catalog where name_lower in (milch, brot); res:=res||'11 B sieht A: '||n||'; ';

  -- 12: mehr als 200 Namen.
  begin perform public.catalog_note_use(array_fill('x'::text, array[201]), null); res:=res||'12 201 Namen: ERLAUBT(!); ';
  exception when others then res:=res||'12 201 Namen: verweigert; '; end;
  -- 13: App darf watch_session_claim nicht aufrufen.
  begin perform public.watch_session_claim(a); res:=res||'13 authenticated claim: ERLAUBT(!); ';
  exception when others then res:=res||'13 authenticated claim: verweigert; '; end;

  -- 14: anon darf nicht zählen.
  reset role; set local role anon;
  perform set_config('request.jwt.claims', json_build_object('role','anon')::text, true);
  begin perform public.catalog_note_use(array[milch], null); res:=res||'14 anon zählt: ERLAUBT(!); ';
  exception when others then res:=res||'14 anon zählt: verweigert; '; end;

  -- 15–17: Aufruf-Grenze als service_role (Edge Function).
  reset role; set local role service_role;
  ok := public.watch_session_claim(a); res:=res||'15 erster Aufruf: '||ok||'; ';
  ok := public.watch_session_claim(a); res:=res||'16 zweiter Aufruf sofort: '||ok||'; ';
  reset role;   -- Zeitpunkt als Datenbank-Besitzer zurückdatieren (now() steht in einer Transaktion still)
  update private.watch_session_requests set last_requested_at = now() - interval '11 seconds' where user_id = a;
  set local role service_role;
  ok := public.watch_session_claim(a); res:=res||'17 nach 11 s: '||ok||'; ';
  -- 18: Tabelle ist für die App nicht lesbar.
  reset role; set local role authenticated;
  begin select count(*) into n from private.watch_session_requests; res:=res||'18 App liest Grenze: ERLAUBT(!); ';
  exception when others then res:=res||'18 App liest Grenze: verweigert; '; end;
  reset role;
  raise exception 'ERGEBNIS (zurückgerollt): %', res;
end $$;
