-- 021_receipts_archive.sql
-- Kassenzettel-Archiv (26.09.2026, design-handoff/KASSENZETTEL_ARCHIV.md)
--
-- Beim „Preise speichern“ legt die App (wenn „Fotos der Bons speichern“ an ist) einen Archiv-Eintrag an:
--   public.receipts           – Laden, Datum, Summe, Zähler, Pfade der Fotos
--   Bucket receipt-images     – <list_id>/<receipt_id>/<n>.jpg (privat, JPEG, ≤ 1,5 MB je Foto)
-- Sichtbar für alle Mitglieder der Liste, auf der eingekauft wurde (wie Artikelfotos).
-- Löschen dürfen der Ersteller und der Besitzer der Liste. Preispunkte hängen nicht am Bon und bleiben.
--
-- Reihenfolge in der App (wiederholbar, offline-fest):
--   Anlegen:  erst Fotos hochladen (upsert), dann Zeile einfügen → andere sehen nie einen Eintrag ohne Fotos.
--   Löschen:  erst Fotos entfernen, dann Zeile. Fotos ohne Zeile (Abbruch mittendrin) darf jedes Mitglied
--             der Liste entfernen, sonst blieben sie für immer liegen.
--
-- Konto löschen: Bons auf eigenen Listen verschwinden mit der Liste (on delete cascade);
-- auf fremden Listen bleibt der Bon, created_by wird NULL (on delete set null).
-- Offen wie bei Artikelfotos: Storage-Dateien gelöschter Listen bleiben liegen (braucht Edge Function).

-- ---------------------------------------------------------------------------------------------
-- 1. Tabelle
-- ---------------------------------------------------------------------------------------------
create table if not exists public.receipts (
  id                uuid primary key,
  list_id           uuid not null references public.lists(id) on delete cascade,
  created_by        uuid references public.profiles(id) on delete set null,
  store_name        text not null default '',
  purchased_at      date not null,
  total             numeric(10,2) not null default 0,
  line_count        integer not null default 0,
  saved_price_count integer not null default 0,
  photo_paths       text[] not null,
  bytes             integer not null default 0,
  created_at        timestamptz not null default now(),
  constraint receipts_store_len    check (length(store_name) <= 100),
  constraint receipts_total_range  check (total >= 0 and total < 100000),
  constraint receipts_counts       check (line_count between 0 and 500 and saved_price_count between 0 and 500),
  constraint receipts_photo_count  check (cardinality(photo_paths) between 1 and 10),
  constraint receipts_bytes        check (bytes between 0 and 16000000)
);

create index if not exists idx_receipts_list_purchased on public.receipts (list_id, purchased_at desc, created_at desc);
create index if not exists idx_receipts_created_by on public.receipts (created_by);   -- Fremdschlüssel (Konto löschen)

alter table public.receipts enable row level security;

-- Nur für angemeldete Nutzer; kein UPDATE (ein Bon ändert sich nach dem Speichern nicht).
revoke all on public.receipts from anon;
grant select, insert, delete on public.receipts to authenticated;

drop policy if exists receipts_select on public.receipts;
drop policy if exists receipts_insert on public.receipts;
drop policy if exists receipts_delete on public.receipts;
create policy receipts_select on public.receipts for select to authenticated
  using (list_id = any (array(select private.accessible_list_ids())));
create policy receipts_insert on public.receipts for insert to authenticated
  with check (created_by = (select auth.uid()) and private.has_list_access(list_id)
              -- Fotos nur aus dem eigenen Ordner <list_id>/<id>/ (keine fremden Dateien einhängen)
              and not exists (select 1 from unnest(photo_paths) p
                              where p not like list_id::text || '/' || id::text || '/%' or length(p) > 200));
create policy receipts_delete on public.receipts for delete to authenticated
  using (created_by = (select auth.uid()) or private.is_list_owner(list_id));

-- ---------------------------------------------------------------------------------------------
-- 2. Bucket und Regeln
-- ---------------------------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipt-images', 'receipt-images', false, 1572864, array['image/jpeg'])
on conflict (id) do update
  set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Zweiter Ordner des Pfads (<list_id>/<receipt_id>/…) als UUID, sonst NULL.
create or replace function private.storage_receipt_uuid(p_name text)
returns uuid
language sql
immutable
set search_path = public
as $$
  select case when (storage.foldername(p_name))[2] ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
              then ((storage.foldername(p_name))[2])::uuid end;
$$;

-- Gibt es zum Pfad schon eine Archiv-Zeile? Danach sind die Fotos unveränderlich.
create or replace function private.receipt_row_exists(p_name text)
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select exists (select 1 from public.receipts r where r.id = private.storage_receipt_uuid(p_name));
$$;

-- Darf die Fotos eines Bons löschen: Ersteller oder Listenbesitzer; gibt es die Zeile nicht (mehr),
-- jedes Mitglied der Liste (Aufräumen nach Abbruch).
create or replace function private.can_delete_receipt_file(p_name text)
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select case
    when exists (select 1 from public.receipts r where r.id = private.storage_receipt_uuid(p_name))
      then exists (select 1 from public.receipts r
                   where r.id = private.storage_receipt_uuid(p_name)
                     and r.list_id = public.storage_folder_uuid(p_name)
                     and (r.created_by = auth.uid() or private.is_list_owner(r.list_id)))
    else private.has_list_access(public.storage_folder_uuid(p_name))
  end;
$$;

revoke all on function private.storage_receipt_uuid(text), private.receipt_row_exists(text),
                       private.can_delete_receipt_file(text) from public, anon;
grant execute on function private.storage_receipt_uuid(text), private.receipt_row_exists(text),
                          private.can_delete_receipt_file(text) to authenticated;

drop policy if exists receipt_images_read   on storage.objects;
drop policy if exists receipt_images_insert on storage.objects;
drop policy if exists receipt_images_update on storage.objects;
drop policy if exists receipt_images_delete on storage.objects;
create policy receipt_images_read on storage.objects for select to authenticated
  using (bucket_id = 'receipt-images' and private.has_list_access(public.storage_folder_uuid(name)));
-- Hochladen und Überschreiben (upsert nach Abbruch) nur, solange die Zeile noch fehlt.
create policy receipt_images_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'receipt-images' and private.storage_receipt_uuid(name) is not null
              and not private.receipt_row_exists(name)
              and private.has_list_access(public.storage_folder_uuid(name)));
create policy receipt_images_update on storage.objects for update to authenticated
  using (bucket_id = 'receipt-images' and not private.receipt_row_exists(name)
         and private.has_list_access(public.storage_folder_uuid(name)))
  with check (bucket_id = 'receipt-images' and private.storage_receipt_uuid(name) is not null
              and not private.receipt_row_exists(name)
              and private.has_list_access(public.storage_folder_uuid(name)));
create policy receipt_images_delete on storage.objects for delete to authenticated
  using (bucket_id = 'receipt-images' and private.can_delete_receipt_file(name));
