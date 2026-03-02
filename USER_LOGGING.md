# Benutzerfreundliches Logging-System

## Übersicht

Famlist verfügt nun über zwei parallele Logging-Systeme:

1. **Developer-Logging** (`Logger.swift`) - Technische Logs mit Funktionsnamen, Dateipfaden und Zeilennummern
2. **User-Logging** (`UserLogger.swift`) - Verständliche Logs für Nicht-Entwickler in deutscher Sprache

## Filter-Anleitung

### In Xcode Console

Um nur die benutzerfreundlichen Logs zu sehen, verwenden Sie einen der folgenden Filter:

```
[👤 USER]
```

oder in der Xcode Console Filter-Box einfach eingeben:
```
👤 USER
```

### Beispiel-Output

**Vorher (nur Developer-Logs):**
```
[LOG] init(config:) @Famlist/SupabaseClient.swift:97 [supabaseHost=mbfztpbwfktiduemqqfe.supabase.co, persistSession=true] → SupabaseClient initialized
[LOG] restoreSession() @Famlist/AuthService.swift:83 [{hasSession=true}] → 3A9830F9-9166-4E80-8C12-315D2FDAE545
```

**Jetzt (mit User-Logs):**
```
[👤 USER] [14:23:20] 🔄 Sitzung wird wiederhergestellt...
[👤 USER] [14:23:21] ✅ Sitzung wiederhergestellt
[👤 USER] [14:23:21] 👤 Benutzerprofil wird geladen...
[👤 USER] [14:23:21] ✅ Benutzerprofil geladen
[👤 USER] [14:23:22] 📋 Liste 'Einkaufsliste Rob' geladen (31 Artikel)
[👤 USER] [14:23:25] ✅ Alle 31 Artikel als erledigt markiert
[👤 USER] [14:23:26] ✅ Synchronisierung abgeschlossen (31 Artikel)
```

## Verwendung im Code

### Kategorien

Das UserLog-System ist in Kategorien organisiert:

#### 1. **Auth** - Authentifizierungs-Events
```swift
// Anmeldung gestartet
UserLog.Auth.loginStarted(email: "user@example.com")

// Erfolgreich angemeldet
UserLog.Auth.loginSuccess(username: "Max Mustermann")

// Anmeldung fehlgeschlagen
UserLog.Auth.loginFailed(reason: "Falsches Passwort")

// Session wird wiederhergestellt
UserLog.Auth.restoringSession()
UserLog.Auth.sessionRestored()

// Profil laden
UserLog.Auth.loadingProfile()
UserLog.Auth.profileLoaded()

// Abmelden
UserLog.Auth.loggedOut()
```

#### 2. **Sync** - Synchronisierungs-Events
```swift
// Synchronisierung gestartet
UserLog.Sync.started()

// Daten synchronisieren
UserLog.Sync.syncing(itemCount: 25)

// Synchronisierung abgeschlossen
UserLog.Sync.completed(itemCount: 25)

// Synchronisierung fehlgeschlagen
UserLog.Sync.failed(reason: "Keine Internetverbindung")

// Echtzeit-Update empfangen
UserLog.Sync.realtimeUpdate(itemName: "Milch")

// Offline/Online-Modus
UserLog.Sync.offlineMode()
UserLog.Sync.onlineMode()
```

#### 3. **Data** - Daten-Events (Listen, Artikel)
```swift
// Liste laden
UserLog.Data.loadingList(name: "Einkaufsliste")
UserLog.Data.listLoaded(name: "Einkaufsliste", itemCount: 42)

// Artikel hinzufügen
UserLog.Data.itemAdded(name: "Milch")

// Artikel aktualisieren
UserLog.Data.itemUpdated(name: "Butter 250g")

// Artikel löschen
UserLog.Data.itemDeleted(name: "Käse")

// Alle Artikel abhaken/zurücksetzen
UserLog.Data.allItemsChecked(count: 31)
UserLog.Data.allItemsUnchecked(count: 31)

// Erledigte Artikel entfernen
UserLog.Data.checkedItemsRemoved(count: 15)

// Import aus Zwischenablage
UserLog.Data.clipboardImport(count: 10)
```

#### 4. **UI** - UI-Events
```swift
// App gestartet
UserLog.UI.appLaunched()

// Hauptansicht geladen
UserLog.UI.mainViewLoaded()

// Ansicht gewechselt
UserLog.UI.viewChanged(to: "Profil")

// Bilder laden
UserLog.UI.loadingImage()
UserLog.UI.imageLoaded()

// Cache geleert
UserLog.UI.imageCacheCleared(count: 50)
```

#### 5. **Error** - Fehler-Events
```swift
// Allgemeiner Fehler
UserLog.Error.general(message: "Unerwarteter Fehler beim Laden")

// Netzwerkfehler
UserLog.Error.network(message: "Server nicht erreichbar")
UserLog.Error.network() // Standard-Nachricht

// Datenbankfehler
UserLog.Error.database(message: "Daten konnten nicht gespeichert werden")

// Validierungsfehler
UserLog.Error.validation(field: "E-Mail", message: "Ungültiges Format")

// Unerwarteter Fehler
UserLog.Error.unexpected(details: "Nil-Pointer in LoginViewModel")
```

### Benutzerdefinierte Logs

Für spezielle Fälle können Sie auch eigene Kategorien erstellen:

```swift
UserLog.custom(category: "🎨 Theme", message: "Dark Mode aktiviert")
UserLog.custom(category: "📊 Analytics", message: "Event 'button_click' gesendet")
```

## Ein- und Ausschalten

User-Logs können global deaktiviert werden:

```swift
// User-Logs deaktivieren
UserLog.isEnabled = false

// User-Logs aktivieren (Standard)
UserLog.isEnabled = true
```

Dies ist nützlich für Release-Builds oder wenn Sie nur Developer-Logs sehen möchten.

## Best Practices

1. **Verwenden Sie sprechende Namen**: Statt "Item XYZ" schreiben Sie den tatsächlichen Artikelnamen
2. **Zeitpunkt**: Loggen Sie wichtige Benutzeraktionen und Status-Änderungen
3. **Fehler**: Verwenden Sie immer UserLog.Error für Fehler, damit diese leicht zu finden sind
4. **Nicht übertreiben**: Loggen Sie nicht jeden einzelnen Schritt, sondern nur wichtige Meilensteine
5. **Deutsche Sprache**: Alle User-Logs sollten auf Deutsch und verständlich sein

## Beispiel-Workflow

Typischer App-Start mit User-Logs:

```
[👤 USER] [08:15:00] 🚀 App gestartet
[👤 USER] [08:15:00] 🔄 Sitzung wird wiederhergestellt...
[👤 USER] [08:15:01] ✅ Sitzung wiederhergestellt
[👤 USER] [08:15:01] 👤 Benutzerprofil wird geladen...
[👤 USER] [08:15:01] ✅ Benutzerprofil geladen
[👤 USER] [08:15:02] 📋 Liste 'Einkaufsliste' wird geladen...
[👤 USER] [08:15:02] ✅ Liste 'Einkaufsliste' geladen (25 Artikel)
[👤 USER] [08:15:02] 🏠 Hauptansicht geladen
```

Artikel hinzufügen:

```
[👤 USER] [08:20:15] ➕ Artikel hinzugefügt: Weihenstephan Milch
[👤 USER] [08:20:15] ☁️ Synchronisiere 1 Artikel mit Server...
[👤 USER] [08:20:16] ✅ Synchronisierung abgeschlossen (1 Artikel)
```

Bulk-Aktion:

```
[👤 USER] [10:45:30] ✅ Alle 31 Artikel als erledigt markiert
[👤 USER] [10:45:31] ☁️ Synchronisiere 31 Artikel mit Server...
[👤 USER] [10:45:33] ✅ Synchronisierung abgeschlossen (31 Artikel)
```

## Integration in CI/CD

In automatisierten Tests können Sie User-Logs analysieren, um sicherzustellen, dass wichtige Events geloggt werden:

```swift
// In Tests
XCTAssertTrue(logOutput.contains("[👤 USER]"))
XCTAssertTrue(logOutput.contains("✅ Erfolgreich angemeldet"))
```

## Emoji-Legende

- 🔑 Authentifizierung
- ✅ Erfolg
- ❌ Fehler
- 🔄 Wird geladen / Synchronisierung
- 👤 Benutzer / Profil
- ☁️ Cloud / Server-Operation
- 📡 Echtzeit-Update
- 📋 Liste
- ➕ Hinzufügen
- ✏️ Bearbeiten
- 🗑️ Löschen
- ⬜️ Zurücksetzen
- 📴 Offline
- 📶 Online
- 🌐 Netzwerk
- 💾 Datenbank
- ⚠️ Warnung
- ❗️ Unerwarteter Fehler
- 🖼️ Bild
- 🏠 Hauptansicht
- 👁️ Ansichtswechsel
- 🚀 App-Start

## FAQ

**Q: Kann ich das Emoji-Präfix ändern?**  
A: Ja, in `UserLogger.swift` die Variable `prefix` anpassen.

**Q: Werden User-Logs auch in Production-Builds angezeigt?**  
A: Ja, aber Sie können sie mit `UserLog.isEnabled = false` deaktivieren.

**Q: Kann ich User-Logs in eine Datei schreiben?**  
A: Aktuell werden sie nur in die Console geschrieben. Sie können aber die `log()` Funktion erweitern, um auch in eine Datei zu schreiben.

**Q: Was ist der Unterschied zu os_log?**  
A: UserLog ist einfacher und bietet verständliche deutsche Nachrichten. Zusätzlich wird auch os_log im DEBUG-Modus verwendet für bessere Xcode-Integration.

---

Letzte Aktualisierung: 23.11.2025

