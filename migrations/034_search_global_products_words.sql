-- 034_search_global_products_words.sql
-- Suche „Weitere Produkte“ (30.09.2026): Jedes Wort des Suchbegriffs darf im Namen ODER in der Marke stehen.
--
-- Fehler: „Schokolade“ fand Lidl-Schokolade, „Schokolade Lidl“ fand nichts. Die Funktion aus Migration 020
-- suchte den ganzen Begriff als ein Stück nur im Namen (name_lower LIKE '%schokolade lidl%'); die Marke steht
-- aber in der eigenen Spalte brand. Im Katalog gibt es 20 Produkte mit „Schokolade“ im Namen und Marke „Lidl“.
--
-- Neu:
-- - Der Begriff wird an Leerzeichen in Wörter zerlegt (höchstens 5). Jedes Wort muss in
--   „Name + Leerzeichen + Marke“ vorkommen, die Reihenfolge ist egal („Lidl Schokolade“ = „Schokolade Lidl“).
-- - Wörter ab 3 Zeichen nutzen den neuen Trigramm-Index idx_gpc_search_text_trgm; kürzere Wörter (z. B. „70“)
--   filtern nur mit. Mindestens ein Wort muss 3 Zeichen haben, sonst gibt es keine Treffer (wie bisher).
-- - Sonst unverändert: 3–60 Zeichen, bis zu 300 Kandidaten, davon die 5 beliebtesten (scans_n).
-- Gemessen vor dem Einspielen (Probe-Index, zurückgerollt): „schokolade lidl“ 2,5 ms, 20 Kandidaten;
-- vorher „schokolade“ 16,9 ms.

create index if not exists idx_gpc_search_text_trgm on public.global_product_catalog
  using gin ((lower(coalesce(name, '') || ' ' || coalesce(brand, ''))) gin_trgm_ops);

create or replace function public.search_global_products(p_query text)
returns table(code text, name text, brand text, category text, measure text, image_url text, scans_n integer)
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v_query text := lower(btrim(coalesce(p_query, '')));
  v_expr constant text := $e$lower(coalesce(g.name, '') || ' ' || coalesce(g.brand, ''))$e$;
  v_word text;
  v_pattern text;
  v_where text := '';
  v_has_indexed_word boolean := false;
begin
  if char_length(v_query) < 3 or char_length(v_query) > 60 then
    return;
  end if;
  for v_word in
    select w from unnest(regexp_split_to_array(v_query, '\s+')) as w where w <> '' limit 5
  loop
    if v_where <> '' then v_where := v_where || ' and '; end if;
    if char_length(v_word) >= 3 then
      v_has_indexed_word := true;
      v_pattern := '%' || replace(replace(replace(v_word, '\', '\\'), '%', '\%'), '_', '\_') || '%';
      v_where := v_where || v_expr || ' like ' || quote_literal(v_pattern);
    else
      v_where := v_where || 'strpos(' || v_expr || ', ' || quote_literal(v_word) || ') > 0';
    end if;
  end loop;
  if not v_has_indexed_word then
    return;
  end if;
  return query execute format($q$
    with hits as materialized (
      select g.code, g.name, g.brand, g.category, g.measure, g.image_url, g.scans_n, g.name_lower
      from public.global_product_catalog g
      where %s
      limit 300
    )
    select h.code, h.name, h.brand, h.category, h.measure, h.image_url, h.scans_n
    from hits h
    order by h.scans_n desc nulls last, h.name_lower
    limit 5
  $q$, v_where);
end;
$function$;
