-- 036_match_global_products.sql
-- „Per Foto hinzufügen“ (01.10.2026): Kandidaten für den Abgleich mit der Packungsaufschrift.
--
-- Fehler: Ein Foto von „REWE Bio Süßrahm Butter“ wurde zu „Rewe Bio Erdnussbutter Creamy“. Die App suchte mit
-- search_global_products („rewe butter“), die nur die 5 beliebtesten Produkte liefert, in denen ALLE Wörter
-- irgendwo vorkommen, und nahm den ersten Treffer.
--
-- Neu: match_global_products(p_words) liefert bis zu 30 Kandidaten, in denen mindestens zwei der gelesenen
-- Wörter vorkommen (bei nur einem Wort: dieses), sortiert nach Anzahl Wort-Treffer, dann Beliebtheit.
-- Die App bewertet die Kandidaten danach selbst streng (ganze Wörter, Wörter die nicht auf der Packung stehen
-- geben Abzug, Bildvergleich) und fragt bei Unsicherheit nach.
-- - Höchstens 8 Wörter, je 3–30 Zeichen; nutzt den Trigramm-Index idx_gpc_search_text_trgm (Migration 034).
-- - Ohne diese Funktion (noch nicht eingespielt) fällt die App auf search_global_products zurück.

create or replace function public.match_global_products(p_words text[])
returns table(code text, name text, brand text, category text, measure text, image_url text, scans_n integer, hits integer)
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v_expr constant text := $e$lower(coalesce(g.name, '') || ' ' || coalesce(g.brand, ''))$e$;
  v_word text;
  v_like text;
  v_or text := '';
  v_score text := '';
  v_n integer := 0;
begin
  if p_words is null then
    return;
  end if;
  for v_word in
    select distinct lower(btrim(w)) from unnest(p_words) as w
    where char_length(btrim(w)) between 3 and 30
    limit 8
  loop
    v_like := v_expr || ' like ' || quote_literal('%' || replace(replace(replace(v_word, '\', '\\'), '%', '\%'), '_', '\_') || '%');
    if v_n > 0 then
      v_or := v_or || ' or ';
      v_score := v_score || ' + ';
    end if;
    v_or := v_or || v_like;
    v_score := v_score || '(' || v_like || ')::int';
    v_n := v_n + 1;
  end loop;
  if v_n = 0 then
    return;
  end if;
  return query execute format($q$
    select s.code, s.name, s.brand, s.category, s.measure, s.image_url, s.scans_n, s.hits
    from (
      select g.code, g.name, g.brand, g.category, g.measure, g.image_url, g.scans_n, (%s) as hits
      from public.global_product_catalog g
      where %s
    ) s
    where s.hits >= %s
    order by s.hits desc, s.scans_n desc nulls last
    limit 30
  $q$, v_score, v_or, least(2, v_n));
end;
$function$;

revoke all on function public.match_global_products(text[]) from public, anon;
grant execute on function public.match_global_products(text[]) to authenticated;
