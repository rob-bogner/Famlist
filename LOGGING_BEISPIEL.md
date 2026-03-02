# Logging-Beispiel: Vorher vs. Nachher

## Szenario: App-Start und Artikel abhaken

### VORHER - Nur Developer-Logs

```
[LOG] init(config:) @Famlist/SupabaseClient.swift:97 [supabaseHost=mbfztpbwfktiduemqqfe.supabase.co, persistSession=true, autoRefreshToken=<redacted>] → SupabaseClient initialized
[LOG] init(config:) @Famlist/SupabaseClient.swift:106 [{restored=true}] → Auth session ready
[LOG] init(config:) @Famlist/SupabaseClient.swift:114 [{authEvent=initialSession}] → Void
[LOG] markPhase(_:) @Famlist/AppSessionViewModel.swift:113 [{phase=sessionRestore, label=Restoring session...}] → Void
[LOG] restoreSession() @Famlist/AuthService.swift:83 [{hasSession=true}] → 3A9830F9-9166-4E80-8C12-315D2FDAE545
[LOG] markPhase(_:) @Famlist/AppSessionViewModel.swift:113 [{phase=profile, label=Loading user profile...}] → Void
[LOG] myProfile() @Famlist/SupabaseProfilesRepository.swift:46 [{source=currentUser}] → Profile(id: 3A9830F9-9166-4E80-8C12-315D2FDAE545, publicId: "test_public_id", username: nil, fullName: nil, avatarUrl: nil, createdAt: Optional(2025-09-07 20:13:55 +0000), updatedAt: nil)
[LOG] handleAuthCompletion() @Famlist/AppSessionViewModel.swift:241 [{profileId=3A9830F9-9166-4E80-8C12-315D2FDAE545, action=loadProfile, status=existing}] → Void
[LOG] markPhase(_:) @Famlist/AppSessionViewModel.swift:113 [{phase=defaultList, label=Loading default list...}] → Void
[LOG] fetchDefaultList(for:) @Famlist/SupabaseListsRepository.swift:88 [ownerId=3A9830F9-9166-4E80-8C12-315D2FDAE545, hit=true] → ListModel(id: 10000000-0000-0000-0000-000000000001, ownerId: 3A9830F9-9166-4E80-8C12-315D2FDAE545, title: "Einkaufsliste Rob", isDefault: true, createdAt: 2025-09-01 15:39:17 +0000, updatedAt: 2025-09-07 19:18:44 +0000)
[LOG] handleAuthCompletion() @Famlist/AppSessionViewModel.swift:272 [profileId=3A9830F9-9166-4E80-8C12-315D2FDAE545, defaultListId=10000000-0000-0000-0000-000000000001] → bootstrapped
[LOG] markPhase(_:) @Famlist/AppSessionViewModel.swift:113 [{label=Loading items..., phase=itemsSnapshot}] → Void
[LOG] setupRealtimeChannel(for:onEvent:) @Famlist/SupabaseRealtimeManager.swift:55 [listId=10000000-0000-0000-0000-000000000001, action=setupChannel, channelId=public:items:10000000-0000-0000-0000-000000000001] → Void
[LOG] observeItems(listId:) @Famlist/SupabaseItemsRepository.swift:141 [{listId=10000000-0000-0000-0000-000000000001}] → AsyncStream<Array<ItemModel>>(context: Swift.AsyncStream<Swift.Array<Famlist.ItemModel>>._Context)
[LOG] fetchAndYield(_:) @Famlist/SupabaseItemsRepository.swift:257 [listId=10000000-0000-0000-0000-000000000001, itemsCount=31] → Void
[LOG] setupRealtimeChannel(for:onEvent:) @Famlist/SupabaseRealtimeManager.swift:82 [listId=10000000-0000-0000-0000-000000000001, action=channelSubscribed, channelId=public:items:10000000-0000-0000-0000-000000000001, status=success] → Void
[LOG] performToggleAll() @Famlist/ListViewModel+BulkActions.swift:74 [action=toggleAllItems.start, targetState=true, itemCount=31] → Void
[LOG] batchUpdateItems(_:listId:) @Famlist/SupabaseItemsRepository.swift:413 [action=batchUpdateItems.start, itemCount=31, listId=10000000-0000-0000-0000-000000000001] → Void
[LOG] batchUpdateItems(_:listId:) @Famlist/SupabaseItemsRepository.swift:424 [action=batchUpdateItems.suppressionEnabled, expectedEvents=31, listId=10000000-0000-0000-0000-000000000001] → Void
[LOG] setupRealtimeChannel(for:onEvent:) @Famlist/SupabaseRealtimeManager.swift:114 [listId=10000000-0000-0000-0000-000000000001, action=realtimeUpdate, record={created_at=2025-11-22T07:24:47.726256+00:00, productdescription=<null>, measure=g, price=0, brand=Champignons,, ownerpublicid=<null>, isChecked=true, name=in Scheiben, updated_at=2025-11-23T13:23:25.374324+00:00, position=<null>, id=108814d6-eaff-4638-8af7-9fec6a4014cb, units=200, list_id=10000000-0000-0000-0000-000000000001, category=Obst & Gemüse, imagedata=<redacted>}] → Void
[LOG] decrementEventCounter(for:) @Famlist/SupabaseItemsRepository.swift:92 [action=eventCounter.decrement, remaining=30, listId=10000000-0000-0000-0000-000000000001] → Void
[LOG] processRealtimeEvent(_:listId:) @Famlist/SupabaseItemsRepository.swift:166 [action=processRealtimeEvent.skipped, reason=waitingForBatchEvents, listId=10000000-0000-0000-0000-000000000001] → Void
... (29 weitere ähnliche Einträge) ...
[LOG] fetchAndYield(_:) @Famlist/SupabaseItemsRepository.swift:257 [listId=10000000-0000-0000-0000-000000000001, itemsCount=31] → Void
[LOG] batchUpdateItems(_:listId:) @Famlist/SupabaseItemsRepository.swift:545 [action=batchUpdateItems.completed, itemCount=31, listId=10000000-0000-0000-0000-000000000001] → Void
[LOG] performToggleAll() @Famlist/ListViewModel+BulkActions.swift:124 [action=toggleAllItems.completed, itemCount=31] → Void
```

**Problem:** 
- 📚 Viel zu viel Output (100+ Zeilen für eine einfache Aktion)
- 🤯 Technische Details wie Funktionsnamen, Dateipfade, UUIDs
- 🔤 Englische Begriffe und Code-Vokabular
- 🧩 Schwer zu filtern und zu verstehen

---

### NACHHER - Mit User-Logs (gefiltert nach `[👤 USER]`)

```
[👤 USER] [14:23:20] 🔄 Sitzung wird wiederhergestellt...
[👤 USER] [14:23:21] ✅ Sitzung wiederhergestellt
[👤 USER] [14:23:21] 👤 Benutzerprofil wird geladen...
[👤 USER] [14:23:21] ✅ Benutzerprofil geladen
[👤 USER] [14:23:22] 📋 Liste 'Einkaufsliste Rob' geladen (31 Artikel)
[👤 USER] [14:23:25] ✅ Alle 31 Artikel als erledigt markiert
[👤 USER] [14:23:26] ✅ Synchronisierung abgeschlossen (31 Artikel)
```

**Vorteile:**
- ✨ Übersichtlich: 7 Zeilen statt 100+
- 🇩🇪 Deutsche Sprache
- 😊 Verständliche Beschreibungen
- 🎯 Einfach zu filtern nach `[👤 USER]`
- 📊 Zeitstempel für jeden Log-Eintrag
- 🎨 Emojis für schnelle visuelle Erfassung

---

## Weitere Beispiele

### Artikel hinzufügen

**Developer-Log:**
```
[LOG] addItem(_:) @Famlist/ListViewModel.swift:189 [itemId=ABC123, brand=Weihenstephan, category=Milchprodukte] → Void
[LOG] createItem(_:) @Famlist/SupabaseItemsRepository.swift:45 [listId=10000000-0000-0000-0000-000000000001] → ItemModel(id: "ABC123", name: "Milch", ...)
```

**User-Log:**
```
[👤 USER] [10:30:15] ➕ Artikel hinzugefügt: Weihenstephan Milch
```

---

### Fehler beim Netzwerk

**Developer-Log:**
```
[LOG] batchUpdateItems(_:listId:) @Famlist/SupabaseItemsRepository.swift:413 [action=batchUpdateItems.error, error=The Internet connection appears to be offline.] → Void
```

**User-Log:**
```
[👤 USER] [11:45:30] 🌐 Netzwerkfehler: Keine Verbindung zum Server
[👤 USER] [11:45:30] 📴 Offline-Modus: Änderungen werden lokal gespeichert
```

---

### Anmeldung

**Developer-Log:**
```
[LOG] signInWithEmailPassword(email:password:) @Famlist/AppSessionViewModel.swift:156 [email=user@example.com] → Void
[LOG] signIn(email:password:) @Famlist/AuthService.swift:45 → Session(id: "xyz", user: User(...))
[LOG] handleAuthCompletion() @Famlist/AppSessionViewModel.swift:230 [profileId=3A9830F9-9166-4E80-8C12-315D2FDAE545] → Void
```

**User-Log:**
```
[👤 USER] [09:00:10] 🔑 Anmeldung gestartet für user@example.com
[👤 USER] [09:00:11] ✅ Erfolgreich angemeldet
[👤 USER] [09:00:11] 👤 Benutzerprofil wird geladen...
[👤 USER] [09:00:12] ✅ Benutzerprofil geladen
```

---

## Filter-Anleitung für Xcode Console

### Nur User-Logs anzeigen:
1. Öffnen Sie die Xcode Console (⌘ + Shift + Y)
2. Im Filter-Feld eingeben: `👤 USER`
3. Oder: `[👤 USER]`

### Nur Developer-Logs anzeigen:
```
[LOG]
```

### Nur Fehler anzeigen:
```
[👤 USER] ❌
```
oder
```
[👤 USER] ⚠️
```

### Nur Sync-Events:
```
[👤 USER] 🔄
```
oder
```
[👤 USER] ☁️
```

---

## Kombination beider Systeme

Die besten Ergebnisse erhalten Sie, wenn Sie **beide** Logging-Systeme parallel verwenden:

- **User-Logs** für schnelle Übersicht und Debugging aus Benutzersicht
- **Developer-Logs** für detaillierte technische Analyse und Fehlersuche

Bei einem Problem können Sie zuerst die User-Logs checken, um zu verstehen, was passiert ist, und dann die Developer-Logs für technische Details konsultieren.

---

Erstellt: 23.11.2025

