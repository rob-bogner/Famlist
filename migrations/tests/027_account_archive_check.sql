-- Prüfung von 027_account_archive.sql (Archivieren, Sperre, Hinweise, Besitzer-RPCs, Wiederherstellen).
-- Ausführen im SQL-Editor oder per MCP execute_sql. Verändert nichts: Der Block legt eigene Test-Konten an und
-- endet immer mit RAISE EXCEPTION, dadurch wird alles zurückgerollt. Die Meldung „ERGEBNIS …“ enthält die Ergebnisse.
-- Rollen: A besitzt Liste LA (Mitglied B), B besitzt Liste LB (Mitglied A).
-- Erwartet (Stand 27.09.2026):
--   1 true · 2 60 · 3 0 · 4 owner_archived · 5 member_archived · 6 1 · 7 false · 8 true · 9 1
--   10 0 · 11 0 · 12 verweigert · 13 verweigert · 14 1 · 15 ungültig · 16 A · 17 1 · 18 true · 19 0
--   20 true · 21 true · 22 true · 23 0 · 24 0 · 25 verweigert · 26 true · 27 false · 28 true
--   29 member_archived · 30 false · 31 true · 32 true · 33 verweigert · 34 verweigert · 35 false
do $$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid();
  la uuid := gen_random_uuid(); lb uuid := gen_random_uuid();
  tok text := 'zz027-' || substr(md5(random()::text), 1, 12);
  res text := ''; n int; t text; ok boolean; ts timestamptz; notice uuid;
begin
  -- Setup als postgres
  insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at) values
    ('00000000-0000-0000-0000-000000000000', a, 'authenticated', 'authenticated', 'zz027-a-' || a || '@example.invalid', now(), now()),
    ('00000000-0000-0000-0000-000000000000', b, 'authenticated', 'authenticated', 'zz027-b-' || b || '@example.invalid', now(), now());
  update profiles set full_name = 'A' where id = a;
  update profiles set full_name = 'B' where id = b;
  insert into lists (id, owner_id, title, is_default) values (la, a, 'LA', false), (lb, b, 'LB', false);
  insert into items (list_id, name) values (la, 'Milch'), (lb, 'Brot');
  insert into list_members (list_id, profile_id) values (la, b), (lb, a);
  insert into list_invites (token, list_id, created_by) values (tok, la, a);
  insert into auth.sessions (id, user_id, created_at, updated_at) values (gen_random_uuid(), a, now(), now());

  -- A löscht das Konto (wie die App)
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.delete_my_account();
  reset role;

  res := res || '1 archiviert: ' || private.is_archived(a) || '; ';
  select extract(day from purge_after - archived_at)::int into n from private.account_archive where user_id = a;
  res := res || '2 Frist Tage: ' || n || '; ';
  select count(*) into n from list_members where list_id = la; res := res || '3 Mitglieder LA: ' || n || '; ';
  select reason into t from private.archived_memberships where list_id = la and profile_id = b;
  res := res || '4 LA/B: ' || coalesce(t, '-') || '; ';
  select reason into t from private.archived_memberships where list_id = lb and profile_id = a;
  res := res || '5 LB/A: ' || coalesce(t, '-') || '; ';
  select count(*) into n from account_notices where recipient_id = b and subject_id = a and seen_at is null;
  res := res || '6 Hinweis an B: ' || n || '; ';
  select exists (select 1 from list_members where list_id = lb and profile_id = a) into ok;
  res := res || '7 A noch in LB: ' || ok || '; ';
  select revoked_at is not null into ok from list_invites where token = tok;
  res := res || '8 Einladung widerrufen: ' || ok || '; ';
  select count(*) into n from auth.sessions where user_id = a; res := res || '9 Sitzungen A: ' || n || '; ';

  -- B sieht LA nicht mehr (auch keine Artikel)
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select count(*) into n from lists where id = la; res := res || '10 B sieht LA: ' || n || '; ';
  select count(*) into n from items where list_id = la; res := res || '11 B sieht Artikel LA: ' || n || '; ';
  reset role;

  -- A (archiviert, Token noch gültig) darf nichts lesen oder anlegen
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    insert into lists (owner_id, title, is_default) values (a, 'neu', false);
    res := res || '12 A legt Liste an: ERLAUBT; ';
  exception when insufficient_privilege then res := res || '12 A legt Liste an: verweigert; ';
  end;
  begin
    update lists set title = 'x' where id = la;
    get diagnostics n = row_count;
    res := res || '13 A ändert LA: ' || case when n = 0 then 'verweigert' else 'ERLAUBT' end || '; ';
  exception when insufficient_privilege then res := res || '13 A ändert LA: verweigert; ';
  end;
  select count(*) into n from public.my_account_status(); res := res || '14 Status A: ' || n || '; ';
  begin
    perform public.accept_list_invite(tok);
    res := res || '15 A nimmt Einladung an: ERLAUBT; ';
  exception when insufficient_privilege or no_data_found then res := res || '15 A nimmt Einladung an: ungültig; ';
  end;
  reset role;

  -- B: archivierte Mitglieder von LB, Hinweis gelesen
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select name into t from public.archived_list_members(lb); res := res || '16 archiviert in LB: ' || coalesce(t, '-') || '; ';
  select count(*), min(id::text)::uuid into n, notice from account_notices where seen_at is null;
  res := res || '17 B ungelesene Hinweise: ' || n || '; ';
  res := res || '18 gelesen markiert: ' || public.mark_notice_seen(notice) || '; ';
  select count(*) into n from account_notices where seen_at is null; res := res || '19 danach: ' || n || '; ';
  reset role;

  -- A stellt wieder her
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  res := res || '20 wiederhergestellt: ' || public.restore_my_account() || '; ';
  reset role;
  select exists (select 1 from list_members where list_id = la and profile_id = b) into ok; res := res || '21 B wieder in LA: ' || ok || '; ';
  select exists (select 1 from list_members where list_id = lb and profile_id = a) into ok; res := res || '22 A wieder in LB: ' || ok || '; ';
  select count(*) into n from private.archived_memberships where list_id in (la, lb); res := res || '23 Archiveinträge: ' || n || '; ';
  select count(*) into n from private.account_archive where user_id = a; res := res || '24 Archivzustand A: ' || n || '; ';

  -- Besitzer entfernt archiviertes Mitglied → kommt nicht zurück
  perform private.archive_account(a);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    perform public.remove_archived_member(la, a);
    res := res || '25 B entfernt aus LA (nicht Besitzer): ERLAUBT; ';
  exception when insufficient_privilege then res := res || '25 B entfernt aus LA (nicht Besitzer): verweigert; ';
  end;
  res := res || '26 B entfernt A aus LB: ' || public.remove_archived_member(lb, a) || '; ';
  reset role;
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.restore_my_account();
  reset role;
  select exists (select 1 from list_members where list_id = lb and profile_id = a) into ok; res := res || '27 A wieder in LB: ' || ok || '; ';
  select exists (select 1 from list_members where list_id = la and profile_id = b) into ok; res := res || '28 B wieder in LA: ' || ok || '; ';

  -- Beide archiviert: A zuerst, dann B; A stellt wieder her, B noch archiviert
  perform private.archive_account(a);
  perform private.archive_account(b);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.restore_my_account();
  reset role;
  select reason into t from private.archived_memberships where list_id = la and profile_id = b;
  res := res || '29 LA/B nach Restore A: ' || coalesce(t, '-') || '; ';
  select exists (select 1 from list_members where list_id = la and profile_id = b) into ok; res := res || '30 B in LA: ' || ok || '; ';
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  perform public.restore_my_account();
  reset role;
  select exists (select 1 from list_members where list_id = la and profile_id = b) into ok; res := res || '31 B wieder in LA: ' || ok || '; ';
  select not exists (select 1 from private.archived_memberships where list_id in (la, lb)) into ok; res := res || '32 Archiv leer: ' || ok || '; ';

  -- Rechte
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    perform public.admin_delete_user(a, 'archive');
    res := res || '33 admin_delete_user als Nutzer: ERLAUBT; ';
  exception when insufficient_privilege then res := res || '33 admin_delete_user als Nutzer: verweigert; ';
  end;
  begin
    perform public.archived_list_members(la);
    res := res || '34 fremde archivierte Mitglieder: ERLAUBT; ';
  exception when insufficient_privilege then res := res || '34 fremde archivierte Mitglieder: verweigert; ';
  end;
  res := res || '35 Status B: ' || exists (select 1 from public.my_account_status()) || '; ';
  reset role;

  raise exception 'ERGEBNIS %', res;
end $$;
