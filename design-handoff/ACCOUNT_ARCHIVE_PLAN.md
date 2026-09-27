# Plan: Konto archivieren, nach 60 Tagen löschen, wiederherstellen

Stand 27.09.2026 · Phase 0 (Bestandsaufnahme) · Grundlage: `design-handoff/PROMPT_ACCOUNT_ARCHIVE.md`
Alle Fakten unten sind live im Projekt `mbfztpbwfktiduemqqfe` bzw. im Code geprüft (Datei:Zeile).

---

## 1. Bestandsaufnahme

### 1.1 Datenbank

| Punkt | Befund |
|---|---|
| Zugriffsregeln | Fast alle Regeln laufen über 4 Hilfsfunktionen: `private.accessible_list_ids()`, `is_list_owner()`, `is_list_member()`, `has_list_access()`. Daran hängen: `lists_select`, `items_access`, `receipts_select`, `list_members_select`, Realtime-Kanal `list:<id>`, Storage `item-images` und `receipt-images`. |
| Folge | Wer keine Zeile in `list_members` mehr hat, verliert **überall** sofort den Zugriff auf die Liste. Für „geteilte Listen verschwinden sofort“ braucht es deshalb keine neue Regel für die anderen Nutzer. |
| Direkte Besitzer-Regeln | `lists_insert/update/delete` (`owner_id = auth.uid()`), `categories_*`, `price_points_*`, `item_catalog_own`, `profiles_update`, Storage `avatars_own_*`, `catalog_images_own`. Diese prüfen die Hilfsfunktionen nicht. |
| Mitglied entfernen | Trigger `trg_list_member_removed` → `on_list_member_removed()`: widerruft Einladungen und schickt `realtime.send('member_removed')` an `user:<profile_id>`. |
| Einladungen | `create_list_invite` prüft `has_list_access`. `accept_list_invite` prüft nur Token und Ablaufdatum, nicht den Zustand des Besitzers. |
| Zeitgesteuerte Jobs | `pg_cron` ist installiert, der Job `tombstone-gc` läuft täglich um 03:00. `pg_net` ist **nicht** installiert (Version 0.14.0 verfügbar). `supabase_vault` ist installiert. |
| Storage | Direktes `DELETE` auf `storage.objects` blockiert der Trigger `storage.protect_delete`. `SELECT` ist erlaubt, Pfade lassen sich also per SQL ermitteln. |
| Sitzungen | `auth.refresh_tokens.session_id` → `auth.sessions` mit `ON DELETE CASCADE`. Löscht man `auth.sessions` des Nutzers, können seine anderen Geräte die Sitzung nicht mehr verlängern. |

### 1.2 App

| Punkt | Befund |
|---|---|
| Routing | `RootView.swift:34-50`: Splash → (angemeldet) ProfileSetup / AcceptInvite / ShoppingList → sonst SignIn. |
| Anmeldeablauf | `handleAuthCompletion` (`AppSessionViewModel+Auth.swift:132-162`) läuft nach jeder Anmeldung **und beim Kaltstart** (`restoreSession`, :98-127). Er lädt das Profil (zuerst aus `ProfileCache`), dann `startList` → `ensure_default_list`, Realtime, `isAuthenticated = true`. |
| Konto löschen heute | `deleteAccount()` (`+Account.swift:158-175`) → `SupabaseProfilesRepository.deleteAccount()` (:137-144): **löscht zuerst das Avatar-Bild**, dann RPC `delete_my_account`, dann `signOut` → `resetLocalState`. Offline gibt es nur einen festen Fehlertext. |
| Lokales Löschen | `resetLocalState()` (`AppSessionViewModel.swift:177-189`) leert SwiftData, Sync-Warteschlange, Kataloge, `ProfileCache`, Listen-Einstellungen. |
| Mitglieder | `ShareMembersViewModel` + `ShareMembersSheet`; Mitglieder per Join `list_members → profiles` (`SupabaseListsRepository.swift:208-237`). |
| Realtime pro Nutzer | Kanal `user:<uuid>`, Event `member_removed` (`SupabaseListsRepository.swift:172-197`) → `handleMembershipRemoval` (`ListViewModel+RealtimeSync.swift:250-270`). |
| Toasts | `GlassToast`, `StatusToast`, `UndoToast`, Fehler-Toast in `ShoppingListView+Overlays.swift:141-165`. |
| Edge Functions | Aufruf per `invokeFunction` (`SupabaseClient.swift:143`), bisher nur `watch-session`. Muster für JWT-Prüfung: `supabase/functions/watch-session/index.ts`. |
| Repository-Conformer | `ProfilesRepository`: Supabase, Preview, `MockProfilesRepository`, `StubProfiles`. `ListsRepository`: Supabase, Offline, Preview, `MockListsRepository`, `StubLists`, `FakeRemoteLists`, `JoinLists`. Neue Methoden brauchen Standard-Implementierungen im Protokoll, damit die Mocks nicht brechen. |

### 1.3 Design (freigegeben)
Boards in `Design/html/`: `RestoreAccount` (Zustände `default`, `loading`, `offline`, `confirm` = RestorePurgeDialog), `MemberDeletedToast`, `ShareMembers` (Varianten `archived`, `confirmRemove`), `DeleteAccount` (neuer Text). Die Dateien mit ~1 KB sind Varianten, die die Hauptkomponente mit einem anderen Zustand einbinden.

---

## 2. Datenmodell (Migration 027)

**Archivzustand in einer privaten Tabelle, nicht in `profiles`.** Grund: `profiles_update` erlaubt jedem Nutzer, seine eigene Zeile zu ändern. Stünde `purge_after` in `profiles`, könnte ein Nutzer die Löschfrist selbst verschieben. Außerdem bleibt `profiles` für Build 1 unverändert.

| Tabelle | Spalten | Zweck |
|---|---|---|
| `private.account_archive` | `user_id` (PK, FK auth.users cascade), `archived_at`, `purge_after`, `display_name` | Ein Eintrag = Konto ist archiviert. |
| `private.archived_memberships` | `list_id` (FK lists cascade), `profile_id`, `role`, `added_at`, `reason` (`owner_archived` \| `member_archived`), `archived_at`; PK (`list_id`, `profile_id`) | Gesicherte Mitgliedschaften zum Zurückschreiben. |
| `public.account_notices` | `id`, `recipient_id` (FK profiles cascade), `list_id` (FK lists cascade), `subject_id`, `subject_name`, `kind` (`member_archived`), `created_at`, `seen_at` | Gespeicherter Hinweis für den Listenbesitzer (auch offline). RLS: nur `recipient_id = auth.uid()` darf lesen und `seen_at` setzen. |

Hilfsfunktion `private.is_archived(uuid)` und `private.caller_active()` (= `not is_archived(auth.uid())`).

---

## 3. Funktionen (RPCs)

| Funktion | Aufrufer | Wirkung |
|---|---|---|
| `private.archive_account(uid)` | intern | Eigene Listen: alle Mitgliedschaften nach `archived_memberships` (`owner_archived`) kopieren und löschen. Fremde Listen: eigene Mitgliedschaft kopieren (`member_archived`) und löschen, Hinweis an den Besitzer speichern + `realtime.send('member_archived')` an `user:<owner>`. Alle Einladungen der eigenen Listen widerrufen. `account_archive` anlegen (`purge_after = now() + 60 Tage`). `realtime.send('account_archived')` an `user:<uid>` (andere eigene Geräte). Alle `auth.sessions` des Nutzers löschen. |
| `delete_my_account()` | App (auch Build 1) | Gleicher Name und gleiche Signatur, ruft jetzt `archive_account(auth.uid())` auf. |
| `my_account_status()` | App | Liefert `archived_at`, `purge_after` oder nichts. |
| `restore_my_account()` | App | Nur `auth.uid()`, nur wenn archiviert und `purge_after > now()`. Schreibt Mitgliedschaften zurück (Details §3.1), löscht den Archiveintrag. |
| `archived_list_members(list_id)` | App (Besitzer) | Archivierte Mitglieder der Liste mit Name und `purge_after`. Nur für den Besitzer. |
| `remove_archived_member(list_id, profile_id)` | App (Besitzer) | Löscht den Archiveintrag (`member_archived`). Die Person kommt beim Wiederherstellen nicht zurück. |
| `mark_notice_seen(id)` | App | Setzt `seen_at`. |
| `admin_delete_user(uid, mode)` | nur Service-Role | `archive` → `archive_account`. `purge` → falls nötig archivieren, `purge_after = now()`, dann Löschlauf sofort anstoßen (§4). |

### 3.1 Zurückschreiben beim Wiederherstellen
- Einträge `owner_archived` meiner Listen: Mitglied aktiv → zurück in `list_members`. Mitglied selbst archiviert → Eintrag auf `member_archived` umstellen, damit er mit dessen Wiederherstellung zurückkommt.
- Einträge `member_archived` mit mir als Mitglied: Liste existiert und Besitzer aktiv → zurück in `list_members`. Besitzer archiviert → Eintrag auf `owner_archived` umstellen.
- Entfernt der Besitzer die Person während der Frist, ist der Eintrag gelöscht und kommt nicht zurück.

### 3.2 Sperre für archivierte Konten selbst
Ein archiviertes Konto kann sich anmelden (nötig zum Wiederherstellen). Bis dahin darf es keine Daten lesen oder ändern. Außerdem kann ein anderes Gerät noch bis zu eine Stunde ein gültiges Zugangs-Token haben (Laufzeit des Tokens laut Supabase-Standard, für dieses Projekt ungeprüft).
- `accessible_list_ids`, `is_list_owner`, `is_list_member` liefern für ein archiviertes Konto nichts bzw. `false`. Das deckt Listen, Artikel, Kassenzettel, Realtime und Storage-Fotos ab.
- `lists_insert/update/delete` bekommen zusätzlich `private.caller_active()`.
- `accept_list_invite`, `create_list_invite` und `invite_preview_by_token` lehnen archivierte Aufrufer und archivierte Listenbesitzer ab.
- Nicht gesperrt: `categories`, `price_points`, `item_catalog`, `profiles` (lesen). Ein Schreiben dort schadet nicht und wird mitgelöscht. `profiles_select` für die eigene Zeile bleibt, damit die App das Profil laden kann.

---

## 4. Endgültiges Löschen (Migration 028 + Edge Functions)

**Warum `pg_net` nötig ist:** Die Fotos lassen sich nur über die Storage-API löschen, also nur aus einer Edge Function. `pg_cron` kann eine Edge Function nur über HTTP aufrufen, und HTTP aus Postgres heraus geht nur mit `pg_net`. Eine andere Möglichkeit ohne `pg_net` gibt es nicht; auch der Cron-Assistent im Supabase-Dashboard nutzt `pg_net`.

| Baustein | Inhalt |
|---|---|
| `account_purge_due(limit)` (nur Service-Role) | Konten mit `purge_after <= now()`, höchstens `limit` Stück. |
| `account_storage_paths(uid)` (nur Service-Role) | Alle Dateien aus `storage.objects`: `avatars/<uid>/`, `catalog-images/<uid>/`, `item-images/<eigene list_id>/`, `receipt-images/<eigene list_id>/`. |
| `account_purge_rows(uid)` (nur Service-Role) | Nur wenn archiviert und fällig. Löscht wie `delete_my_account` heute, zusätzlich `archived_memberships` (beide Richtungen), `account_notices` (als Empfänger und als Betroffener), `account_archive`, zuletzt `auth.users`. |
| Edge Function `account-purge` | Arbeitet alle fälligen Konten ab: Pfade holen → `storage.remove` in Blöcken zu 1000 → prüfen, dass keine Datei übrig ist → erst dann `account_purge_rows`. Fehlt noch eine Datei, bleibt das Konto für den nächsten Lauf stehen. Protokolliert Anzahl Konten und Dateien. Die Function löscht nur, was ohnehin fällig ist. Deshalb braucht sie keinen geheimen Schlüssel für den Aufruf; der öffentliche Anon-Schlüssel reicht. |
| Edge Function `purge-my-account` | Prüft das JWT (Muster `watch-session`), akzeptiert nur ein archiviertes Konto der eigenen UID, setzt `purge_after = now()` und führt denselben Löschweg sofort aus (gemeinsamer Code in `supabase/functions/_shared/purge.ts`). |
| Cron-Job `account-purge` | Täglich 03:30 per `net.http_post` auf die Edge Function. |
| `watch-session` | Lehnt archivierte Konten mit 403 ab. |

---

## 5. App

| Bereich | Änderung |
|---|---|
| Repository | `AccountRepository` (neu, eigene Datei + Supabase-Implementierung + Preview): `status()`, `restore()`, `purge()`, `archivedMembers(listId:)`, `removeArchivedMember(...)`, `unseenNotices()`, `markNoticeSeen(_:)`. Neues Protokoll statt Erweiterung, damit die 11 bestehenden Mocks unverändert bleiben. |
| Anmeldung | `handleAuthCompletion`: **vor** `loadProfile` online `status()` abfragen. Archiviert → `archivedAccount` setzen, nichts laden, keine Liste anlegen, kein Realtime. Offline → wie bisher weiter (Offline-First); die Server-Sperre (§3.2) verhindert Schäden, und die nächste Online-Anmeldung zeigt den Screen. |
| Routing | `RootView`: neuer erster Zweig `archivedAccount != nil` → `RestoreAccountView`. |
| RestoreAccountView | Nach Board `RestoreAccount`: Datum gelöscht / endgültig, Resttage-Chip, Karte „Das bekommst du zurück“, „Angemeldet als <E-Mail>“, Knöpfe Wiederherstellen / Abmelden / Endgültig löschen. Zustände Laden, Offline, Bestätigen (RestorePurgeDialog). ViewModel `RestoreAccountViewModel` (@MainActor) mit UserLog. |
| Konto löschen | Avatar **nicht mehr** vorab löschen (sonst fehlt es beim Wiederherstellen). Neuer Text laut Board. Offline-Meldung vor dem Aufruf. |
| Andere eigene Geräte | Event `account_archived` auf `user:<uid>` → lokal abmelden und `resetLocalState`. |
| Hinweis für Besitzer | Event `member_archived` + beim Start `unseenNotices()`. Toast `MemberDeletedToast` in der betroffenen Liste, sobald sie offen ist; danach `markNoticeSeen`. |
| Mitglieder & Teilen | Besitzer sieht archivierte Mitglieder ausgegraut („Konto gelöscht · bis <Datum> wiederherstellbar“) mit „Entfernen“ → confirmationDialog → `removeArchivedMember`. |
| UserLog | Konto archiviert, wiederhergestellt, Wiederherstellen fehlgeschlagen, endgültig gelöscht, archiviertes Mitglied entfernt. |
| Previews / Tests | `#Preview` Light + Dark je Screen. Unit-Tests: Anmeldeablauf mit archiviertem Status (Screen, Wiederherstellen, Abmelden, endgültig löschen, offline). UI-Test mit Fixture für RestoreAccount. |

---

## 6. Phasen

| Phase | Inhalt | Prüfung |
|---|---|---|
| 1 | Migration 027: Tabellen, Archivieren, Wiederherstellen, Sperre §3.2, Besitzer-RPCs, Hinweise | SQL-Test `migrations/tests/027_account_archive_check.sql` (zurückgerollt), live eingespielt |
| 2 | Migration 028: `pg_net`, Lösch-Hilfsfunktionen, Cron-Job; Edge Functions `account-purge`, `purge-my-account`; `watch-session` | Live-Test mit Wegwerf-Konto inklusive hochgeladener Fotos: archivieren → Frist künstlich ablaufen lassen → Lauf → Konto, Zeilen und Dateien weg |
| 3 | App: AccountRepository, Anmeldeablauf, RestoreAccountView, Konto-löschen-Text, andere Geräte | Build grün, Unit-Tests grün, Simulator |
| 4 | App: Besitzer-Hinweis (Toast), archivierte Mitglieder in „Mitglieder & Teilen“ | Build grün, Unit-Tests grün, Test mit zwei Konten |
| 5 | SPEC.md §2/§3/§5, MyListUI-Referenz, UI-Tests, Abgleich mit den Boards, TestFlight-Build 2 | UI-Tests grün, Screenshots Light/Dark |

Je Phase ein Commit, kein Push ohne Okay.

---

## 7. Risiken und Nebenwirkungen

| Risiko | Folge | Umgang |
|---|---|---|
| **Build 1 (TestFlight) nach Phase 1** | Build 1 löscht vor dem Archivieren das Avatar-Bild. Meldet sich jemand mit Build 1 nach dem Archivieren wieder an, schlägt die Anmeldung fehl (Sperre §3.2 blockiert `ensure_default_list`), einen Restore-Screen gibt es dort nicht. | Betrifft nur Robert und Sofie. In Build 1 nicht „Konto löschen“ benutzen, bis Build 2 da ist. |
| Zurückgeschriebene Mitgliedschaft | Ob Mitglieder die Liste ohne Neustart sofort wieder sehen, ist ungeprüft. Die App hört nur auf `member_removed`, nicht auf ein Hinzufügen. | In Phase 4 mit zwei Geräten testen; falls nötig ein Event `member_restored` ergänzen. |
| Admin-Archivierung ohne angemeldeten Nutzer | Der Trigger `on_list_member_removed` widerruft dann alle Einladungen der fremden Liste (weil `auth.uid()` leer ist). | In `archive_account` bewusst so hinnehmen oder den Trigger anpassen; Entscheidung in Phase 1 dokumentieren. |
| Offline-Kaltstart eines archivierten Kontos | Die App zeigt kurz die lokalen Daten, bis sie online ist. | Server blockiert jeden Zugriff; `account_archived` meldet ab. Bewusst Offline-First. |
| Rechtliches | Ob 60 Tage mit der DSGVO vereinbar sind, ist nicht geprüft. | Robert. |

---

## 8. Umsetzung (Stand 27.09.2026, Branch `account-archive`)

| Phase | Commit | Ergebnis |
|---|---|---|
| 1 | `8df6662` | Migration 027 live; SQL-Test `027_account_archive_check.sql`: 35 Prüfungen wie erwartet |
| 2 | `b08588c` | Migration 028 live (`pg_net`, Cron 03:30); Edge Functions `account-purge`, `purge-my-account`, `watch-session` v2; Live-Test mit 2 Wegwerf-Konten (4 bzw. 1 Foto, Konto und Zeilen weg; 409 für aktive Konten; 403 für `admin_delete_user` als Nutzer) |
| 3 | `0432f70` | App: RestoreAccountView, RestorePurgeDialog, Konto-löschen-Text, Anmeldeablauf, Kanal `user:<id>` einmal abonniert; 27 neue Unit-Tests, Suite 706 grün |
| 4 | `efc072a` | App: MemberDeletedToast, archivierte Mitglieder in „Mitglieder & Teilen“; 5 neue Unit-Tests |
| 5 | (dieser Commit) | Fixture-Screens, 4 UI-Tests, Screenshot-Abgleich, Build 2 |

### Entscheidungen bei der Umsetzung

- **Kein eigenes RestoreAccountViewModel.** Die Logik liegt in `AppSessionViewModel+Archive.swift`, weil der Archivzustand das Routing in `RootView` steuert. Die View hält nur ihren Anzeigezustand (lädt, bestätigt, Fehlertext).
- **Archiv-Prüfung beim Start:** Ohne lokale Profilkopie (erste Anmeldung auf dem Gerät) fragt die App vorher. Mit Kopie startet sie sofort und fragt im Hintergrund; ist das Konto archiviert, verwirft sie die lokalen Daten und zeigt RestoreAccount. Grund: Ein Kaltstart ohne Netz darf nicht auf eine Zeitüberschreitung warten.
- **Ein Abonnement für `user:<id>`:** `observeMemberRemovals` leitet sich aus `observeUserEvents` ab. Test-Doubles bekommen eine Standard-Umsetzung, die nur `memberRemoved` liefert.
- **Konto löschen** löscht das Profilfoto nicht mehr vorab (es muss beim Wiederherstellen zurückkommen).

### Abweichungen vom Design

| Stelle | Design | Umsetzung | Grund |
|---|---|---|---|
| MemberDeletedToast | „Sofie hat ihr Konto gelöscht“, „Sie ist nicht mehr Mitglied …“ | „Sofie hat das Konto gelöscht“, „Sofie ist nicht mehr Mitglied dieser Liste. Wird das Konto wiederhergestellt, ist Sofie automatisch wieder dabei.“ | Die App kennt das Geschlecht nicht. |
| ArchivedMemberRemove | „Stellt sie ihr Konto wieder her, kommt sie …“ | „Wird das Konto wiederhergestellt, kommt Sofie nicht mehr automatisch zurück. Du kannst Sofie später neu einladen.“ | wie oben |
| RestoreAccount | nur Offline-Hinweis | Schlägt Wiederherstellen oder endgültiges Löschen online fehl, erscheint derselbe rote Hinweis mit Warn-Icon und „Das hat nicht geklappt. Bitte versuche es erneut.“ | Fehlerfall nicht gestaltet; vorhandene Box wiederverwendet. |
| Anmelden | – | Wird das Konto auf einem anderen Gerät gelöscht, meldet sich dieses Gerät ab und zeigt über die vorhandene Fehlermeldung: „Dein Konto wurde auf einem anderen Gerät gelöscht. Melde dich an, um es wiederherzustellen.“ | Fall nicht gestaltet. |
| Konto löschen | – | Ohne Netz: „Zum Löschen brauchst du eine Internetverbindung.“ an der Stelle des Beschreibungstexts (wie bisherige Fehler). | Fall nicht gestaltet. |
| Resttage-Chip | „Noch 60 Tage“ | Einzahl „Noch 1 Tag“ | Grammatik |

### Nicht umgesetzt (mit Grund)

- **SPEC.md, PLAN.md, MyListUI:** nicht angefasst. Den Ordner `design-handoff/` gleicht die Design-Sitzung laufend mit dem Canvas ab (`Design/SYNC.md`); SPEC.md §2/§3 enthält die neuen Screens bereits. Eine SwiftUI-Referenz in MyListUI wäre eine zweite Kopie der App-Views.
- **Test mit zwei echten Geräten** (Realtime-Hinweis, Liste verschwindet und kommt zurück): nur mit TestFlight-Build 2 möglich. Die Server-Seite (Broadcasts, Zugriffe) ist per SQL-Test geprüft, das Auswerten der Nachrichten per Unit-Test.
