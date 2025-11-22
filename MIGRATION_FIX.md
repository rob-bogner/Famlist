# 🔧 SwiftData Migration Fix

## Problem
Die CRDT-Felder wurden zu ItemEntity hinzugefügt, aber die bestehende Datenbank kann nicht automatisch migrieren.

## ✅ Fix Applied
Alle CRDT-Felder sind jetzt **optional** (`?`), was Lightweight Migration ermöglicht.

## 🚀 Nächste Schritte

### Option 1: Simulator zurücksetzen (Schnellste Lösung)

**Wenn du im iOS Simulator testest:**

```bash
# Simulator vollständig zurücksetzen
xcrun simctl erase all

# Oder nur die Famlist App Daten löschen
xcrun simctl uninstall booted com.yourcompany.Famlist
```

**In Xcode:**
1. Stop the app (Cmd+.)
2. Product → Clean Build Folder (Shift+Cmd+K)
3. iOS Simulator → Device → Erase All Content and Settings...
4. Product → Run (Cmd+R)

### Option 2: Physisches Device - App neu installieren

**Auf einem echten iPhone/iPad:**
1. App vom Device löschen (lange drücken → "App löschen")
2. In Xcode: Clean Build Folder (Shift+Cmd+K)
3. Product → Run (Cmd+R)

### Option 3: Programmatisch Datenbank löschen (Für Testing)

Falls du häufig das Schema änderst, kannst du einen Debug-Button hinzufügen:

```swift
// In einer Debug-View oder Settings
Button("Reset Database (Debug)") {
    let storeURL = URL.applicationSupportDirectory
        .appendingPathComponent("Default.store")
    try? FileManager.default.removeItem(at: storeURL)
    exit(0) // App neu starten
}
```

## ✨ Nach dem Reset

Die App sollte jetzt:
1. ✅ Ohne Fehler starten
2. ✅ Neue Items mit CRDT-Feldern erstellen
3. ✅ Alte Items (falls vorhanden) mit nil CRDT-Feldern laden
4. ✅ CRDT-Felder beim ersten Update initialisieren

## 📝 Was wurde geändert

### ItemEntity.swift
- Alle CRDT-Felder sind jetzt **optional** (`Int64?`, `String?`, `Bool?`)
- Default-Werte wurden auf `nil` gesetzt
- Backward compatible mit alten Daten

### SyncEngine.swift & RealtimeEventProcessor.swift  
- Nil-Coalescing beim Lesen alter Entities
- Automatische Initialisierung fehlender CRDT-Felder
- Fallback auf aktuelle Zeit/Default-Werte

## 🎯 Verifikation

Nach App-Neustart:
1. Item erstellen → `hlcTimestamp`, `hlcCounter`, etc. sollten gesetzt sein
2. Check Console für Migration-Errors → sollten verschwunden sein
3. SwiftData Container sollte erfolgreich laden

## 💡 Future: Production Migration

Für Production-Deployment (mit echten User-Daten):

**Option A: Feature-Flag**
```swift
// Neue CRDT-Features nur für neue Items aktivieren
if item.hlcTimestamp == nil {
    // Alter Item, kein CRDT Sync
} else {
    // Neuer Item, volle CRDT-Unterstützung
}
```

**Option B: Background Migration**
```swift
// Beim App-Start alle Items ohne CRDT-Felder initialisieren
Task {
    let items = try itemStore.fetchItems(listId: listId)
    for item in items where item.hlcTimestamp == nil {
        item.hlcTimestamp = Int64(item.createdAt.timeIntervalSince1970 * 1000)
        item.hlcCounter = 0
        item.hlcNodeId = UIDevice.current.identifierForVendor?.uuidString ?? ""
    }
    try itemStore.save()
}
```

## 🆘 Troubleshooting

### Fehler bleibt bestehen nach Reset
```bash
# Derived Data löschen
rm -rf ~/Library/Developer/Xcode/DerivedData

# Xcode komplett neu starten
killall Xcode
open Famlist.xcodeproj
```

### "Store still fails to load"
- Prüfe ob Default.store wirklich gelöscht wurde
- Simulator komplett beenden und neu starten
- Prüfe ob alle CRDT-Felder in ItemEntity optional (`?`) sind

