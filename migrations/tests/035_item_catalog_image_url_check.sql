-- Prüfung von 035_item_catalog_image_url.sql. Verändert nichts (RAISE am Ende rollt alles zurück).
-- Erwartet: 1 Adresse gespeichert · 2 Upsert ohne image_url behält sie (wie die App) · 3 http abgelehnt
do $$
declare
  me uuid; url text := 'https://images.openfoodfacts.org/images/products/000/002/081/5356/front_en.146.400.jpg';
  got text; res text := '';
begin
  select p.id into me from public.profiles p where not private.is_archived(p.id) order by p.created_at limit 1;
  perform set_config('request.jwt.claims', json_build_object('sub',me,'role','authenticated')::text, true);
  set local role authenticated;

  insert into public.item_catalog (owner_public_id, name, measure, price, image_url)
    values (me::text, 'Probe 035', '', 0, url)
    on conflict (owner_public_id, name_lower) do update set image_url = excluded.image_url;
  select image_url into got from public.item_catalog where owner_public_id = me::text and name_lower = 'probe 035';
  res := res || '1 gespeichert: ' || (got = url) || '; ';

  insert into public.item_catalog (owner_public_id, name, measure, price)
    values (me::text, 'Probe 035', 'g', 0)
    on conflict (owner_public_id, name_lower) do update set measure = excluded.measure;
  select image_url into got from public.item_catalog where owner_public_id = me::text and name_lower = 'probe 035';
  res := res || '2 bleibt: ' || (got = url) || '; ';

  begin
    update public.item_catalog set image_url = 'http://x.example/a.jpg'
      where owner_public_id = me::text and name_lower = 'probe 035';
    res := res || '3 http: ERLAUBT(!); ';
  exception when check_violation then res := res || '3 http: abgelehnt; '; end;

  reset role;
  raise exception 'ERGEBNIS (zurückgerollt): %', res;
end $$;
