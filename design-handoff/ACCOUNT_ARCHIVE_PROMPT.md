# One-Shot-Prompt: Konto archivieren, nach 60 Tagen löschen, wiederherstellen

```
Baue für Famlist „Konto löschen mit 60 Tagen Frist“: Löschen archiviert das Konto, Anmelden innerhalb der Frist
stellt es wieder her, danach wird alles endgültig gelöscht – auch die Fotos. Das Design ist von Robert freigegeben
(27.09.2026, siehe „Design“) – jetzt die Umsetzung in App und Backend.

## Lies zuerst
1. claude.md / CLAUDE.md (Projektregeln, Design-Regeln „Hybrid“, UserLog nur in ViewModels, eine Type je Datei).
2. design-handoff/SPEC.md (§4 Designregeln, §5 „Noch nicht gestaltet“) und design-handoff/MyListUI/README.md.
3. Bestehender Screen: design-handoff/Design/html/DeleteAccount(.dc|Dark.dc).html und
   design-handoff/MyListUI/Screens/AccountScreens.swift; Onboarding-Stil: SignIn.dc.html, ProfileSetup.dc.html.
4. App: Famlist/App/AppSessionViewModel+Auth.swift (handleAuthCompletion, loadProfile),
   Famlist/App/AppSessionViewModel+Account.swift (deleteAccount → RPC delete_my_account),
   Famlist/Repositories/Implementations/SupabaseListsRepository.swift (observeMemberRemovals).
5. migrations/ (zuletzt 026) und migrations/tests/.

## Entscheidungen von Robert (27.09.2026) – nicht erneut fragen
- „Konto löschen“ archiviert das Konto. Nach 60 Tagen wird es mit allen Daten endgültig gelöscht.
- Wer sich innerhalb der 60 Tage wieder anmeldet, sieht einen Screen „Konto wiederherstellen“ und kann das Konto
  vollständig zurückholen.
- Eigene Listen, die mit anderen geteilt sind, verschwinden bei den anderen SOFORT. Endgültig gelöscht werden sie
  erst nach 60 Tagen (bis dahin wiederherstellbar, samt Mitgliedern).
- Fotos (Avatar, Produktfotos, Kassenzettel) werden nach 60 Tagen endgültig gelöscht.
- Eine Verwaltungsfunktion admin_delete_user(p_user_id uuid, p_mode text) mit p_mode 'archive' oder 'purge',
  aufrufbar nur mit dem Service-Role-Schlüssel (nicht aus der App).
- Mitgliedschaften in FREMDEN Listen kommen beim Wiederherstellen automatisch zurück – außer der Listenbesitzer hat
  die Person in der Zwischenzeit aus der Liste entfernt. (Umsetzung: Die archivierte Mitgliedschaft bleibt in der
  Archivtabelle; entfernt der Besitzer die Person während der Frist, wird der Archiveintrag gelöscht und beim
  Wiederherstellen nicht zurückgeschrieben.)
- Während der Frist sieht der Listenbesitzer die Person in „Mitglieder & Teilen“ ausgegraut als „Konto gelöscht ·
  bis <Datum> wiederherstellbar“ mit Knopf „Entfernen“. Bestätigung per Systemdialog: „Stellt sie ihr Konto wieder
  her, kommt sie nicht mehr automatisch zurück. Du kannst sie später neu einladen.“ → RPC (z. B.
  remove_archived_member(list_id, profile_id), nur für den Besitzer) löscht den Archiveintrag.
- RestoreAccount bietet zusätzlich „Jetzt endgültig löschen“ an – mit Bestätigungsdialog und dem Hinweis, dass
  alle Daten sofort und unwiderruflich gelöscht werden. Das löscht sofort über denselben Purge-Weg wie der
  tägliche Job (inkl. Fotos per Storage-API). Aus der App über eine Edge Function (z. B. purge-my-account), die
  das JWT prüft, nur archivierte Konten der eigenen UID akzeptiert und intern mit Service-Role löscht.
- Der Besitzer einer geteilten Liste bekommt einen Hinweis, wenn ein Mitglied sein Konto löscht: „<Name> hat
  ihr/sein Konto gelöscht – ist nicht mehr Mitglied dieser Liste. Stellt sie/er das Konto wieder her, ist sie/er
  automatisch wieder dabei.“ Anzeige als Hinweis (Toast) in der betroffenen Liste. Muss auch ankommen, wenn der
  Besitzer gerade offline ist (Realtime-Ereignis an user:<owner_id> PLUS gespeicherter, einmalig angezeigter
  Hinweis, z. B. Tabelle für Hinweise mit gelesen-Markierung).

## Design (freigegeben; Boards liegen in design-handoff/Design/html/)
Artboard 390 × 844, 1 CSS-px = 1 pt, Light UND Dark. Alle Knöpfe im Glas-Stil (wie FAB).
Nur Original-SVG-Icons (keine SF Symbols), Outfit für Titel, DM Sans für Text, Akzent aus AccentScale.
Die Boards (RestoreAccount*, RestorePurgeDialog*, MemberDeletedToast*, ShareMembersArchived*,
ArchivedMemberRemove*, DeleteAccount, ShareMembers) liegen bereits in Design/html. Liefern: SwiftUI-Referenz in MyListUI/Screens/AccountScreens.swift, SPEC.md §2/§3
ergänzen und den Punkt aus §5 entfernen.

1. RestoreAccount (neu) – erscheint direkt nach dem Anmelden, wenn das Konto archiviert ist.
   Titel „Konto wiederherstellen?“, „Du hast dein Konto am 27.09.2026 gelöscht. Dein Konto wird am 26.11.2026
   endgültig gelöscht.“, Hinweis-Chip „Noch 60 Tage“ (Resttage), Karte „Das bekommst du zurück“: Listen und Artikel,
   Fotos, geteilte Listen samt Mitgliedern, Listen anderer (sofern niemand dich entfernt hat).
   „Angemeldet als <E-Mail>“, Primärknopf „Konto wiederherstellen“, darunter nebeneinander „Abmelden“ und
   „Endgültig löschen“ (rot). Zustände: Laden (Spinner „Wird wiederhergestellt …“, Nebenknöpfe gesperrt),
   Offline („Zum Wiederherstellen brauchst du eine Internetverbindung.“).
   Boards: RestoreAccount, RestoreAccountLoading, RestoreAccountOffline (+ Dark).
2. RestorePurgeDialog (neu) – „Jetzt endgültig löschen?“: „Alle deine Daten werden sofort und unwiderruflich
   gelöscht: Listen, Artikel, Fotos und Kassenzettel. Geteilte Listen verschwinden für alle Mitglieder. Das lässt
   sich nicht rückgängig machen.“ Knöpfe „Endgültig löschen“ (rot) und „Abbrechen“.
3. DeleteAccount (Text geändert) – „Dein Konto wird sofort deaktiviert. Deine geteilten Listen verschwinden bei
   allen Mitgliedern, und aus Listen anderer wirst du entfernt.“ + Hinweisfeld „Meldest du dich innerhalb von
   60 Tagen wieder an, kannst du alles wiederherstellen. Danach wird alles endgültig gelöscht.“ Knopf „Konto löschen“.
4. MemberDeletedToast (neu) – Hinweis für den Listenbesitzer in der Liste (siehe Entscheidungen).
5. ShareMembersArchived (neu, Zustand von ShareMembers) – archiviertes Mitglied ausgegraut mit „Entfernen“;
   ArchivedMemberRemove – Bestätigungsdialog (iOS confirmationDialog).

## Geprüfte Fakten (27.09.2026, Supabase-Projekt mbfztpbwfktiduemqqfe) – darauf aufbauen
- delete_my_account() löscht heute sofort: items + list_members der eigenen Listen, lists, eigene list_members,
  item_catalog (owner_public_id = uid::text), categories, profiles, auth.users. Fotos werden NICHT gelöscht.
  Name und Signatur beibehalten: TestFlight-Build 1 (Robert, Sofie) ruft genau diese RPC auf.
- Tabellen mit Nutzerbezug: lists.owner_id, list_members.profile_id, categories.profile_id (ohne FK!),
  item_catalog.owner_public_id (text, ohne FK!), price_points.profile_id (FK cascade), receipts.created_by
  (FK set null), list_invites.created_by (FK cascade), private.watch_session_requests.user_id (FK cascade).
  items.last_modified_by ist eine Geräte-ID, kein Nutzer. Artikel, die jemand in FREMDE Listen eingetragen hat,
  gehören der Liste und bleiben erhalten.
- Storage-Pfade: avatars/<user_id>/…, catalog-images/<user_id>/…, item-images/<list_id>/…,
  receipt-images/<list_id>/<receipt_id>/…
- Direktes DELETE auf storage.objects blockiert der Trigger storage.protect_delete („Use the Storage API instead“);
  Löschen der Zeile ließe die Datei verwaist. Fotos also nur über die Storage-API löschen (Edge Function mit
  Service-Role), vor dem Löschen der DB-Zeilen, damit die Pfade noch bekannt sind.
- pg_cron ist installiert, pg_net NICHT (für einen Cron-Aufruf einer Edge Function nötig – begründen, falls aktiviert).
- Löschen einer list_members-Zeile löst trg_list_member_removed aus: realtime.send('member_removed') an
  user:<profile_id>; die App entfernt die Liste dann sofort (observeMemberRemovals → handleMembershipRemoval).
  Außerdem werden Einladungen der Liste widerrufen. → „Sofort verschwinden“ = Mitgliedschaften in eine
  Archivtabelle kopieren und löschen; beim Wiederherstellen zurückschreiben. Ob Mitglieder eine zurückgeschriebene
  Liste ohne Neustart sofort sehen, ist UNGEPRÜFT – testen.
- Supabase verknüpft eine neue Anmeldung mit gleicher, bestätigter E-Mail automatisch mit dem bestehenden Konto
  (Identity Linking) → ein archiviertes Konto wird beim erneuten Anmelden gefunden, die UID bleibt gleich.
- profiles wird von der App mit expliziter Spaltenliste gelesen (SupabaseProfilesRepository.columns): neue Spalten
  brechen Build 1 nicht. Profile.publicId ist nicht optional – nichts daran ändern, was NULL liefern kann.
- Der Trigger handle_new_user vergibt seit Migration 026 public_id und created_at.

## Umfang Backend (Migration 027 ff., jede als Datei in migrations/, einzeln live einspielen, sofort testen)
- Archiv-Zustand (z. B. profiles.archived_at, purge_after) und private Archivtabelle(n) für Mitgliedschaften.
- archive_account(uid): Mitgliedschaften archivieren + löschen (eigene Listen: alle Mitglieder; fremde Listen:
  die Person selbst), offene Einladungen der eigenen Listen widerrufen, Sitzungen der Person beenden,
  archived_at/purge_after = now() + 60 Tage setzen, Besitzer fremder Listen benachrichtigen (Realtime + gespeicherter
  Hinweis). delete_my_account() ruft das künftig auf.
- restore_my_account(): nur für auth.uid(), nur innerhalb der Frist; Mitgliedschaften zurückschreiben, soweit Liste
  und Mitglied noch existieren, nicht selbst archiviert sind und der Archiveintrag nicht vom Besitzer entfernt
  wurde; Archivzustand löschen.
- RLS/RPCs: Listen, Artikel, Kassenzettel archivierter Besitzer sind für andere unsichtbar; accept_list_invite und
  create_list_invite lehnen archivierte Besitzer ab. Die watch-session Edge Function lehnt archivierte Konten ab.
- purge: täglicher Job (pg_cron), idempotent, in Stapeln. Erst Fotos per Storage-API (alle vier Buckets nach den
  Pfaden oben), dann alle Zeilen (wie delete_my_account heute + Archivtabellen + Hinweise), zuletzt auth.users.
  Schlägt das Löschen der Fotos fehl, DB-Zeilen behalten und am nächsten Tag erneut versuchen. Protokollieren,
  wie viele Konten und Dateien gelöscht wurden.
- purge-my-account (Edge Function, aus RestoreAccount „Endgültig löschen“) nutzt denselben Purge-Weg sofort.
- admin_delete_user(p_user_id, p_mode) wie oben; 'purge' löscht sofort (inkl. Fotos über denselben Weg).
- SQL-Tests in migrations/tests/ nach dem Muster der vorhandenen Dateien.

## Umfang App
- handleAuthCompletion: ist das Profil archiviert, RestoreAccount zeigen statt die App zu starten; keine Listen
  laden, keine SyncEngine starten, keine lokalen Daten anlegen.
- „Konto wiederherstellen“ → RPC restore_my_account, danach normaler Start. „Abmelden“ → Abmelden wie heute.
  „Endgültig löschen“ → RestorePurgeDialog → purge-my-account → abmelden, lokale Daten entfernen.
- Nach „Konto löschen“ lokal abmelden und lokale Daten entfernen (wie heute).
- MemberDeletedToast in der betroffenen Liste, einmalig pro Hinweis; danach als gelesen markieren.
- ShareMembers: archivierte Mitglieder der Liste (für den Besitzer lesbar über RPC/View) anzeigen, „Entfernen“ →
  Dialog → remove_archived_member.
- UserLog (deutsch) in den ViewModels: Konto archiviert, Konto wiederhergestellt, Wiederherstellen fehlgeschlagen,
  Konto endgültig gelöscht.
- Offline: Löschen, Wiederherstellen und endgültiges Löschen brauchen Netz; klare Meldung, nichts halb ausführen.
- #Preview Light + Dark für jeden neuen Screen; neue Dateien in project.pbxproj; Unit-Tests für den Anmeldeablauf
  mit archiviertem Profil (Restore-Screen, Wiederherstellen, Abmelden, endgültig löschen) und UI-Test mit Fixture.

## Vorgehen
Phase 0: Bestandsaufnahme + design-handoff/ACCOUNT_ARCHIVE_PLAN.md (Datenmodell, RPCs, RLS-Änderungen, Purge-Weg
inkl. Storage, Datenfluss in der App, Risiken). Zeig mir den Plan und stell nur echte Blocker-Fragen.
Danach Phase für Phase: Build grün, Unit-Tests grün, jede Migration live getestet, eigener Commit je Phase,
kein Push ohne Okay. Build und Tests laut CLAUDE.md (Scheme Famlist, Ziele per id=).
```
