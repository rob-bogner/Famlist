# Implementierungsplan: Pessimistic Locking für Bulk Updates

**Erstellt am:** 22. November 2025  
**Status:** Geplant (nicht implementiert)  
**Ziel:** Robuste, timeout-freie Synchronisation bei Bulk-Operationen durch Pessimistic Locking

---

## Übersicht

Ersetze die aktuelle delay-basierte Lösung (`Task.sleep(500ms)`) durch ein Pessimistic Locking-Verfahren, das während Bulk-Operationen Realtime-Events komplett ignoriert und nach Abschluss einen finalen Fetch durchführt.

### Kernprinzip

1. **Setze Lock vor Bulk-Operation** → `suppressRealtimeFetches = true`
2. **Führe alle Updates parallel aus** → TaskGroup
3. **Ignoriere alle Realtime-Events** → Early return in `processRealtimeEvent`
4. **Lock aufheben** → `suppressRealtimeFetches = false`
5. **Finaler Fetch synchronisiert** → `fetchAndYield` holt aktuelle DB-State

### Vorteile gegenüber Delay-Lösung

- ✅ **Kein Timeout-Risiko** bei langsamen Netzwerken/CPUs
- ✅ **Einfacher Code** (Sleep-Delay entfernen)
- ✅ **Robust** unabhängig von Netzwerklatenz
- ✅ **Korrekt** durch finalen Fetch-Sync

### Akzeptierter Trade-off

- Events von anderen Clients werden während Bulk-Operation ignoriert
- **Nicht problematisch**, da:
  - Finaler Fetch holt alle Änderungen nach
  - Bulk-Operationen sind typischerweise kurz (< 2s)
  - CRDT-Semantik stellt Konsistenz sicher

---

## Betroffene Dateien

### Zu modifizierende Dateien

1. **`Famlist/Repositories/Implementations/SupabaseItemsRepository.swift`**
   - `batchUpdateItems()`: Task.sleep entfernen
   - Optional: Stale-Lock-Check einbauen (336h Timeout)

2. **`Famlist/Features/ShoppingList/ViewModels/ListViewModel+BulkActions.swift`**
   - Keine Änderungen notwendig (verwendet bereits `batchUpdateItems`)

### Optional: Neue Hilfsfunktionen

Falls Stale-Lock-Check gewünscht (siehe Schritt 5):
- `checkAndClearStaleLock()` in `SupabaseItemsRepository`

---

## Implementierungsschritte

### Schritt 1: Task.sleep entfernen

**Datei:** `Famlist/Repositories/Implementations/SupabaseItemsRepository.swift`

**Aktuelle Zeilen (ca. 340-345):**
```swift
// Delay to ensure all Realtime events triggered by our updates have arrived.
// This prevents race conditions where Realtime events arrive after we re-enable fetches.
// 500ms should cover network latency and Supabase Realtime event propagation delays.
try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
```

**Aktion:**
- Entferne die gesamte `Task.sleep`-Zeile und den Kommentar darüber
- Behalte die `suppressRealtimeFetches = false` Zeile direkt danach

**Begründung:**
- Lock-basierte Lösung benötigt kein Timeout
- Finaler Fetch synchronisiert automatisch

---

### Schritt 2: Dokumentation aktualisieren

**Datei:** `Famlist/Repositories/Implementations/SupabaseItemsRepository.swift`

**Funktion:** `batchUpdateItems()`

**Neue Kommentare:**
```swift
/// Batch-update multiple items in parallel using pessimistic locking.
///
/// **Strategy:**
/// 1. Acquire lock (`suppressRealtimeFetches = true`) to ignore Realtime events during bulk operation
/// 2. Execute all updates in parallel using TaskGroup
/// 3. Release lock (`suppressRealtimeFetches = false`)
/// 4. Perform final fetch to synchronize with current database state
///
/// **Rationale:**
/// - No timeout/delay needed → robust against network latency
/// - Final fetch ensures consistency regardless of ignored events
/// - Trade-off: Events from other clients during bulk operation are ignored (acceptable, as final fetch syncs state)
///
/// - Parameters:
///   - items: Array of ItemModels to update
///   - listId: The list that the items belong to
/// - Throws: Database errors if any update fails
```

---

### Schritt 3: Kommentare in processRealtimeEvent verdeutlichen

**Datei:** `Famlist/Repositories/Implementations/SupabaseItemsRepository.swift`

**Funktion:** `processRealtimeEvent()`

**Aktueller Kommentar (ca. Zeile 200):**
```swift
// Skip fetch during batch operations to avoid cascade of fetches
// Check BEFORE processing to avoid unnecessary work
```

**Verbesserter Kommentar:**
```swift
// PESSIMISTIC LOCKING: Ignore ALL Realtime events during bulk operations.
// Rationale: Final fetch after bulk operation will sync state correctly.
// This prevents cascading fetches and ensures atomicity of bulk updates.
```

---

### Schritt 4: Error-Handling verifizieren

**Datei:** `Famlist/Repositories/Implementations/SupabaseItemsRepository.swift`

**Funktion:** `batchUpdateItems()`

**Sicherstellen:**
- `catch`-Block setzt `suppressRealtimeFetches = false` zurück ✅ (bereits implementiert)
- Fehler werden korrekt propagiert ✅ (bereits implementiert)

**Kein Änderungsbedarf**, nur Review:
```swift
catch {
    // Re-enable realtime fetches on error
    await MainActor.run {
        self.suppressRealtimeFetches = false
        logVoid(params: (action: "batchUpdateItems.suppressionDisabled.error", listId: listId, error: error.localizedDescription))
    }
    throw error
}
```

---

### Schritt 5 (Optional): Stale-Lock-Protection

**Problem:** Wenn App während Bulk-Operation crashed, bleibt `suppressRealtimeFetches = true` → keine Realtime-Updates mehr.

**Lösung:** Timestamp-basierte Stale-Lock-Detection (336h Timeout).

#### 5.1 Neue Properties hinzufügen

**Datei:** `Famlist/Repositories/Implementations/SupabaseItemsRepository.swift`

**In der Klasse:**
```swift
/// Tracks when the last bulk operation started for stale lock detection.
@MainActor private var lastBulkOperationStartTime: Date?

/// Maximum allowed duration for a bulk operation before considering the lock stale (14 days = 336 hours).
/// After this duration, the lock will be automatically cleared on the next event processing.
private let staleLockThreshold: TimeInterval = 336 * 60 * 60 // 336 hours
```

#### 5.2 Stale-Lock-Check Funktion

```swift
/// Checks if the suppression lock is stale (older than staleLockThreshold) and clears it if necessary.
/// - Returns: True if a stale lock was cleared, false otherwise.
@MainActor
private func checkAndClearStaleLock() -> Bool {
    guard suppressRealtimeFetches,
          let startTime = lastBulkOperationStartTime else {
        return false
    }
    
    let elapsed = Date().timeIntervalSince(startTime)
    if elapsed > staleLockThreshold {
        suppressRealtimeFetches = false
        lastBulkOperationStartTime = nil
        logVoid(params: (
            action: "staleLockCleared",
            reason: "Lock older than \(staleLockThreshold)s (elapsed: \(elapsed)s)"
        ))
        return true
    }
    return false
}
```

#### 5.3 Lock setzen mit Timestamp

**In `batchUpdateItems()`, direkt nach Lock-Aktivierung:**
```swift
await MainActor.run {
    self.suppressRealtimeFetches = true
    self.lastBulkOperationStartTime = Date() // Track start time
    logVoid(params: (action: "batchUpdateItems.suppressionEnabled", listId: listId))
}
```

#### 5.4 Lock aufheben mit Timestamp-Reset

**In `batchUpdateItems()`, beim Lock-Release:**
```swift
await MainActor.run {
    self.suppressRealtimeFetches = false
    self.lastBulkOperationStartTime = nil // Clear timestamp
    logVoid(params: (action: "batchUpdateItems.suppressionDisabled", listId: listId))
}
```

**Auch im catch-Block:**
```swift
await MainActor.run {
    self.suppressRealtimeFetches = false
    self.lastBulkOperationStartTime = nil // Clear timestamp on error too
    logVoid(params: (action: "batchUpdateItems.suppressionDisabled.error", listId: listId, error: error.localizedDescription))
}
```

#### 5.5 Stale-Lock-Check in processRealtimeEvent

**Am Anfang von `processRealtimeEvent()`, vor dem suppressRealtimeFetches-Check:**
```swift
private func processRealtimeEvent(_ event: RealtimeEvent, listId: UUID) async {
    // Check for stale locks first (crash recovery)
    let staleCleared = await MainActor.run { checkAndClearStaleLock() }
    if staleCleared {
        logVoid(params: (action: "processRealtimeEvent.staleLockRecovered", listId: listId))
    }
    
    // Skip fetch during batch operations to avoid cascade of fetches
    let shouldSuppress = await MainActor.run { suppressRealtimeFetches }
    if shouldSuppress {
        logVoid(params: (
            action: "processRealtimeEvent.skipped",
            reason: "batchOperationInProgress",
            listId: listId
        ))
        return
    }
    
    // ... rest of function
}
```

---

## Testing-Strategie

### Manuelle Tests

#### Test 1: Check All (Bulk Operation)
1. Öffne App mit 20+ Items
2. Tippe "Check All"
3. **Erwartung:**
   - Logs zeigen `batchUpdateItems.start`
   - Logs zeigen `suppressionEnabled`
   - Logs zeigen **KEINE** `fetchAndYield`-Calls während TaskGroup
   - Logs zeigen `suppressionDisabled`
   - **Ein** finaler `fetchAndYield`-Call
   - UI aktualisiert sich korrekt (alle Items checked)

#### Test 2: Uncheck All
1. Öffne App mit allen Items gecheckt
2. Tippe "Uncheck All"
3. **Erwartung:**
   - Gleiche Log-Sequenz wie Test 1
   - UI aktualisiert sich korrekt (alle Items unchecked)

#### Test 3: Concurrent Edit von anderem Client (Edge Case)
1. Öffne App auf Device A und Device B
2. Auf Device A: Starte "Check All" für große Liste
3. Auf Device B: **Während** Bulk-Operation editiere ein Item manuell
4. **Erwartung:**
   - Device A: Bulk-Operation läuft durch
   - Device A: Finaler Fetch holt Änderung von Device B nach
   - Device B: Sieht Bulk-Operation von Device A nach Completion
   - **Beide Devices sind nach ~2s synchron**

#### Test 4 (Optional): Stale-Lock-Recovery nach Crash
1. Setze Breakpoint in `batchUpdateItems()` **nach** `suppressRealtimeFetches = true`
2. Starte Bulk-Operation, pausiere am Breakpoint
3. Force-Quit App (nicht debugger stop, sondern App killen)
4. Starte App neu
5. Triggere ein Realtime-Event (z.B. editiere Item auf anderem Device)
6. **Erwartung:**
   - Logs zeigen `staleLockCleared` (wenn mehr als 336h vergangen, sonst skip)
   - Realtime-Events werden normal verarbeitet

### Unit Tests (Optional)

Falls gewünscht, erstelle Test-Cases für:
- `checkAndClearStaleLock()` mit verschiedenen Timestamps
- Mock `suppressRealtimeFetches` in Tests

---

## Rollback-Plan

Falls die Implementierung Probleme verursacht:

### Rollback-Schritte

1. **Git Revert:**
   ```bash
   git revert <commit-hash>
   ```

2. **Manuelle Wiederherstellung des Task.sleep:**
   ```swift
   // In batchUpdateItems(), VOR suppressRealtimeFetches = false:
   try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
   ```

### Indikatoren für notwendigen Rollback

- ❌ UI aktualisiert sich nicht nach Bulk-Operation
- ❌ Logs zeigen `fetchAndYield` während TaskGroup (Lock funktioniert nicht)
- ❌ Crash oder Deadlock während Bulk-Operation
- ❌ Realtime-Updates nach Bulk-Operation dauerhaft deaktiviert (Stale-Lock ohne Recovery)

---

## Zeitabschätzung

### Minimal-Implementierung (Schritte 1-4)
- **Coding:** 15 Minuten
- **Testing:** 30 Minuten
- **Gesamt:** ~45 Minuten

### Mit Stale-Lock-Protection (Schritte 1-5)
- **Coding:** 45 Minuten
- **Testing:** 1 Stunde
- **Gesamt:** ~1h 45min

---

## Nächste Schritte

1. ✅ **Dieser Plan wurde erstellt**
2. ⏳ **Review des Plans durch Entwickler**
3. ⏳ **Implementierung in separatem Branch**
4. ⏳ **Manuelles Testing**
5. ⏳ **Merge in Main bei Erfolg**

---

## Offene Fragen / Diskussion

- Ist Stale-Lock-Protection (Schritt 5) notwendig, oder reicht Minimal-Implementierung?
  - **Empfehlung:** Implementiere Schritt 5, da 336h Timeout extrem robust ist und fast keinen Overhead hat
- Sollen Unit Tests für `checkAndClearStaleLock()` geschrieben werden?
  - **Empfehlung:** Optional, aber empfehlenswert für Regressionssicherheit

---

## Anhang: Vergleich Alt vs. Neu

### ALT (Delay-basiert)
```swift
// Wait for all updates
try await group.waitForAll()

// 500ms delay → PROBLEM bei langsamer Verbindung
try? await Task.sleep(nanoseconds: 500_000_000)

await MainActor.run {
    self.suppressRealtimeFetches = false
}
```

### NEU (Pessimistic Locking)
```swift
// Wait for all updates
try await group.waitForAll()

// Kein Delay → Lock wird einfach aufgehoben
await MainActor.run {
    self.suppressRealtimeFetches = false
    self.lastBulkOperationStartTime = nil
}
```

**Unterschied:** Finaler Fetch synchronisiert unabhängig von Timing → robust & einfach.

