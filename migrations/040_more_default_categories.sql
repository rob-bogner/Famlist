-- 040_more_default_categories.sql
-- Mehr Standard-Kategorien (12.10.2026, Wunsch Robert): 27 statt 8.
--
-- Die App legt für ein neues Konto ab jetzt 27 Kategorien an (ItemCategory.swift). Konten, die es schon gibt,
-- haben nur die alten 8. Diese Migration trägt ihnen die 19 neuen nach.
--
-- Auswahl der Kategorien: Abgleich der Sortimente von Edeka24, Knuspr und myTime (Stand 12.10.2026).
--
-- Regeln:
-- - Betroffen sind nur Konten, die die App schon eingerichtet hat (sie haben die Kategorie „Sonstiges“).
--   Die alten Beispielzeilen ohne Konto (profile_id NULL oder 00000000-…) bleiben unberührt.
-- - Hat ein Konto schon eine Kategorie mit demselben Namen (Groß/Klein egal), wird sie nicht noch einmal angelegt.
-- - Die Reihenfolge des Kontos bleibt erhalten. Jede neue Kategorie kommt direkt hinter eine verwandte alte
--   („Käse“ hinter „Milchprodukte“). Fehlt die alte, kommt die neue ans Ende vor „Sonstiges“.
-- - „Sonstiges“ bleibt immer zuletzt. Danach werden die Positionen neu durchgezählt (0, 1, 2 …).
-- - Icons: nur Schlüssel, die schon im Raster der App stehen (CategoryIconCatalog) – auch ältere App-Versionen
--   zeigen sie richtig an.
-- - Farbe bleibt NULL. Die App leitet die Standardfarbe aus dem Namen ab (CategoryColor.defaults, siehe 033).
-- - Die Migration darf mehrfach laufen: Beim zweiten Mal legt sie nichts an und verschiebt nichts.
-- - Artikel ändert sie nicht (items.category bleibt, wie es ist).

with new_cats(name, icon, anchor, ord) as (
  values
    ('Wurst & Aufschnitt',       'sausage',   'Fleisch & Fisch', 1),
    ('Käse',                     'cheese',    'Milchprodukte',   1),
    ('Eier',                     'egg',       'Milchprodukte',   2),
    ('Vegetarisch & Vegan',      'leaf',      'Milchprodukte',   3),
    ('Frühstück & Aufstriche',   'bowl',      'Backwaren',       1),
    ('Backzutaten',              'flour',     'Backwaren',       2),
    ('Nudeln & Reis',            'pasta',     'Backwaren',       3),
    ('Konserven',                'can',       'Backwaren',       4),
    ('Fertiggerichte',           'pizza',     'Backwaren',       5),
    ('Saucen & Dips',            'jar',       'Backwaren',       6),
    ('Öl, Essig & Gewürze',      'oil',       'Backwaren',       7),
    ('Kaffee, Tee & Kakao',      'cup',       'Backwaren',       8),
    ('Süßigkeiten',              'chocolate', 'Backwaren',       9),
    ('Snacks & Knabbereien',     'cookie',    'Backwaren',      10),
    ('Bier, Wein & Spirituosen', 'wine',      'Getränke',        1),
    ('Drogerie',                 'soap',      'Haushalt',        1),
    ('Baby & Kind',              'baby',      'Haushalt',        2),
    ('Tierbedarf',               'paw',       'Haushalt',        3),
    ('Blumen & Pflanzen',        'flower',    'Haushalt',        4)
),
accounts as (
  select p.id as profile_id
  from public.profiles p
  where exists (select 1 from public.categories c where c.profile_id = p.id and lower(c.name) = 'sonstiges')
),
existing as (
  select c.id, c.profile_id, c.name, c.position::numeric as k1, 0 as k2, (lower(c.name) = 'sonstiges') as is_fallback
  from public.categories c
  join accounts a on a.profile_id = c.profile_id
),
missing as (
  select a.profile_id, n.name, n.icon, n.ord as k2,
         coalesce(
           (select min(e.k1) from existing e where e.profile_id = a.profile_id and lower(e.name) = lower(n.anchor)),
           (select max(e.k1) from existing e where e.profile_id = a.profile_id and not e.is_fallback),
           0) as k1
  from accounts a
  cross join new_cats n
  where not exists (select 1 from public.categories c
                    where c.profile_id = a.profile_id and lower(c.name) = lower(n.name))
),
ordered as (
  select u.*, row_number() over (partition by u.profile_id order by u.is_fallback, u.k1, u.k2, u.name) - 1 as new_pos
  from (
    select id, profile_id, name, null::text as icon, k1, k2, is_fallback, false as is_new from existing
    union all
    select gen_random_uuid(), profile_id, name, icon, k1, k2, false, true from missing
  ) u
),
ins as (
  insert into public.categories (id, profile_id, name, icon, position)
  select id, profile_id, name, icon, new_pos from ordered where is_new
  returning 1
),
upd as (
  update public.categories c
  set position = o.new_pos, updated_at = now()
  from ordered o
  where not o.is_new and c.id = o.id and c.position is distinct from o.new_pos
  returning 1
)
select (select count(*) from ins) as angelegt, (select count(*) from upd) as verschoben;
