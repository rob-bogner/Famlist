-- Prüfung von 034_search_global_products_words.sql. Liest nur.
-- Erwartet: 1 > 0 und alle mit „schokolade“ im Namen/Marke und „lidl“ · 2 = 1 (Reihenfolge egal) · 3 = 5
-- · 4 = 0 (nur kurze Wörter) · 5 = 0 (unter 3 Zeichen) · 6 > 0 (kurzes Wort filtert mit) · 7 = 0 (Joker % zählt nicht)
with
  t1 as (select * from public.search_global_products('Schokolade Lidl')),
  t2 as (select * from public.search_global_products('  lidl   SCHOKOLADE ')),
  t6 as (select * from public.search_global_products('schokolade 70'))
select
  (select count(*) from t1) as "1 schokolade lidl",
  (select bool_and(lower(coalesce(name,'') || ' ' || coalesce(brand,'')) like '%schokolade%'
                   and lower(coalesce(name,'') || ' ' || coalesce(brand,'')) like '%lidl%') from t1) as "1 alle passen",
  ((select array_agg(code order by code) from t1) = (select array_agg(code order by code) from t2))::int as "2 gleich",
  (select count(*) from public.search_global_products('Schokolade')) as "3 schokolade",
  (select count(*) from public.search_global_products('ab cd')) as "4 nur kurze",
  (select count(*) from public.search_global_products('ab')) as "5 zu kurz",
  (select count(*) from t6) as "6 schokolade 70",
  (select count(*) from public.search_global_products('%%%')) as "7 joker";
