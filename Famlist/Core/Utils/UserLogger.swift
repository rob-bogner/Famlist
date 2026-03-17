/*
 UserLogger.swift

 Famlist
 Created on: 23.11.2025
 Last updated on: 17.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Benutzerfreundliches Logging-System für Nicht-Entwickler.
 - Ergänzt das technische Developer-Logging mit verständlichen Nachrichten.

 🛠 Includes:
 - UserLog struct mit Kategorien (Auth, Sync, Daten, UI, Fehler)
 - Eindeutiges Präfix [👤 USER] zum einfachen Filtern
 - Deutsche, sprechende Nachrichten — niemals generische Begriffe

 🔰 Notes for Beginners:
 - Verwenden Sie UserLog.auth(), UserLog.sync(), etc. für benutzerfreundliche Logs
 - Logs können über UserLog.isEnabled global an/ausgeschaltet werden
 - Filter-Tipp: Suche nach "[👤 USER]" um nur User-Logs zu sehen

 📝 Last Change:
 - Refactor (FAM-XX): Konkrete, deterministische User-Logs;
   Infrastruktur-Rauschen entfernt; Bulk-Operationen zusammengefasst.
 ------------------------------------------------------------------------
*/

import Foundation

/// Benutzerfreundliches Logging-System für Nicht-Entwickler.
/// Ergänzt das technische Developer-Logging mit verständlichen deutschen Nachrichten.
///
/// Grundsatz: Jeder Log enthält Artikelname + Menge + konkreten Aktionstyp.
/// Niemals generische Begriffe wie "aktualisiert" oder "geändert" ohne Kontext.
struct UserLog {

    /// Globaler Schalter für User-Logging (standardmäßig aktiviert).
    static var isEnabled: Bool = true

    /// Eindeutiges Präfix für User-Logs (zum einfachen Filtern).
    private static let prefix = "[👤 USER]"

    // MARK: - Private Helper

    /// Formatiert eine Mengenangabe nutzerfreundlich.
    /// - `measure=""` → "Nx"  (z. B. "1x")
    /// - sonst → `"N <localizedMeasure>"` (z. B. "3 Stück", "215 ml")
    private static func formatQuantity(_ units: Int, _ measure: String) -> String {
        if measure.isEmpty {
            return "\(units)x"
        }
        let localizedMeasure = Measure.fromExternal(measure).localizedName
        return "\(units) \(localizedMeasure)"
    }

    // MARK: - Logging-Kategorien

    /// Authentifizierungs- und Profil-Events
    struct Auth {
        static func loginStarted(email: String? = nil) {
            if let email = email {
                log("🔑 Anmeldung gestartet für \(email)")
            } else {
                log("🔑 Anmeldung gestartet")
            }
        }

        static func loginSuccess(username: String? = nil) {
            if let username = username {
                log("✅ Erfolgreich angemeldet als \(username)")
            } else {
                log("✅ Erfolgreich angemeldet")
            }
        }

        static func loginFailed(reason: String? = nil) {
            if let reason = reason {
                log("❌ Anmeldung fehlgeschlagen: \(reason)")
            } else {
                log("❌ Anmeldung fehlgeschlagen")
            }
        }

        static func loggedOut() {
            log("👋 Benutzer abgemeldet")
        }

        static func restoringSession() {
            log("🔄 Sitzung wird wiederhergestellt...")
        }

        static func sessionRestored() {
            log("✅ Sitzung wiederhergestellt")
        }

        static func loadingProfile() {
            log("👤 Benutzerprofil wird geladen...")
        }

        static func profileLoaded(publicId: String? = nil) {
            if let publicId = publicId {
                log("✅ Benutzerprofil geladen (ID: \(publicId))")
            } else {
                log("✅ Benutzerprofil geladen")
            }
        }

        static func authSessionReady() {
            log("🔐 Authentifizierung bereit")
        }

        static func authStateChanged(event: String) {
            log("🔄 Auth-Status: \(event)")
        }

        static func authBootstrapCompleted() {
            log("✅ Initialisierung abgeschlossen")
        }
    }

    /// Synchronisierungs-Events
    struct Sync {
        static func started() {
            log("🔄 Synchronisierung gestartet")
        }

        static func syncing(itemCount: Int) {
            log("☁️ Synchronisiere \(itemCount) Artikel mit Server...")
        }

        static func completed(itemCount: Int? = nil) {
            if let count = itemCount {
                log("✅ Synchronisierung abgeschlossen (\(count) Artikel)")
            } else {
                log("✅ Synchronisierung abgeschlossen")
            }
        }

        static func failed(reason: String? = nil) {
            if let reason = reason {
                log("⚠️ Synchronisierung fehlgeschlagen: \(reason)")
            } else {
                log("⚠️ Synchronisierung fehlgeschlagen")
            }
        }

        static func realtimeUpdate(itemName: String? = nil) {
            if let itemName = itemName {
                log("📡 Echtzeit-Update empfangen für '\(itemName)'")
            } else {
                log("📡 Echtzeit-Update empfangen")
            }
        }

        static func offlineMode() {
            log("📴 Offline-Modus: Änderungen werden lokal gespeichert")
        }

        static func onlineMode() {
            log("📶 Verbindung wiederhergestellt - Synchronisierung läuft")
        }

        static func supabaseInitialized(host: String) {
            log("🔌 Verbindung zu Supabase-Server (\(host)) wird hergestellt...")
        }

        static func realtimePaused(listName: String? = nil) {
            if let listName = listName {
                log("⏸️ Echtzeit-Updates für '\(listName)' pausiert (App im Hintergrund)")
            } else {
                log("⏸️ Echtzeit-Updates pausiert (App im Hintergrund)")
            }
        }

        static func realtimeDisconnected(listName: String? = nil) {
            if let listName = listName {
                log("📴 Echtzeit-Verbindung für '\(listName)' getrennt")
            } else {
                log("📴 Echtzeit-Verbindung getrennt")
            }
        }

        static func realtimeResumed(listName: String? = nil) {
            if let listName = listName {
                log("▶️ Echtzeit-Updates für '\(listName)' fortgesetzt")
            } else {
                log("▶️ Echtzeit-Updates fortgesetzt")
            }
        }

        /// Sync endgültig fehlgeschlagen nach max. Retries
        /// → "⚠️ Synchronisierung fehlgeschlagen: Eier"
        static func itemSyncFailed(name: String, units: Int, measure: String) {
            log("⚠️ Synchronisierung fehlgeschlagen: \(name)")
        }
    }

    /// Daten-Events (Listen, Artikel)
    struct Data {
        static func loadingList(name: String? = nil) {
            if let name = name {
                log("📋 Liste '\(name)' wird geladen...")
            } else {
                log("📋 Liste wird geladen...")
            }
        }

        static func listLoaded(name: String, itemCount: Int) {
            log("✅ Liste '\(name)' geladen (\(itemCount) Artikel)")
        }

        static func listCreated(name: String) {
            log("➕ Liste erstellt: \(name)")
        }

        /// Neuer Artikel hinzugefügt
        /// → "➕ Hinzugefügt: Eier (2 Stück)"
        static func itemAdded(name: String, units: Int? = nil, measure: String? = nil) {
            if let units = units {
                let qty = UserLog.formatQuantity(units, measure ?? "")
                log("➕ Hinzugefügt: \(name) (\(qty))")
            } else {
                log("➕ Hinzugefügt: \(name)")
            }
        }

        /// Artikel bereits vorhanden — Menge erhöht
        /// → "➕ Menge erhöht: Eier (2 → 5 Stück)"
        static func itemCountIncremented(name: String, from oldUnits: Int, to newUnits: Int, measure: String) {
            let newQty = UserLog.formatQuantity(newUnits, measure)
            log("➕ Menge erhöht: \(name) (\(oldUnits) → \(newQty))")
        }

        /// Artikel abgehakt
        /// → "✅ Abgehakt: Eier (5 Stück)"
        static func itemChecked(name: String, units: Int, measure: String) {
            let qty = UserLog.formatQuantity(units, measure)
            log("✅ Abgehakt: \(name) (\(qty))")
        }

        /// Abhaken rückgängig gemacht
        /// → "↩️ Abgehakt entfernt: Eier (5 Stück)"
        static func itemUnchecked(name: String, units: Int, measure: String) {
            let qty = UserLog.formatQuantity(units, measure)
            log("↩️ Abgehakt entfernt: \(name) (\(qty))")
        }

        /// Menge manuell geändert
        /// → "✏️ Menge geändert: Eier (5 → 3 Stück)"
        static func itemQuantityChanged(name: String, from oldUnits: Int, to newUnits: Int, measure: String) {
            let newQty = UserLog.formatQuantity(newUnits, measure)
            log("✏️ Menge geändert: \(name) (\(oldUnits) → \(newQty))")
        }

        /// Reaktivierung eines gelöschten Artikels
        /// → "♻️ Gelöschten Artikel wiederhergestellt: Brot (1 Stück)"
        static func itemReactivated(name: String, units: Int, measure: String) {
            let qty = UserLog.formatQuantity(units, measure)
            log("♻️ Gelöschten Artikel wiederhergestellt: \(name) (\(qty))")
        }

        /// Artikel bearbeitet (Name, Kategorie, Marke o. ä. — keine Mengenänderung)
        /// → "✏️ Milch bearbeitet"
        static func itemUpdated(name: String, units: Int? = nil, measure: String? = nil) {
            log("✏️ \(name) bearbeitet")
        }

        /// Artikel entfernt
        /// → "🗑️ Artikel entfernt: Milch (3 Stück)"
        static func itemDeleted(name: String, units: Int, measure: String) {
            let qty = UserLog.formatQuantity(units, measure)
            log("🗑️ Artikel entfernt: \(name) (\(qty))")
        }

        /// Alle Artikel der Liste entfernt
        /// → "🗑️ Alle N Artikel entfernt"
        static func allItemsDeleted(count: Int) {
            log("🗑️ Alle \(count) Artikel entfernt")
        }

        /// Abgehakte Artikel entfernt
        /// ≤5 → Namen aufführen als Bullet-Liste, >5 → Anzahl
        static func checkedItemsDeleted(items: [(name: String, units: Int, measure: String)]) {
            if items.count <= 5 {
                let bullets = items.map { "  • \($0.name)" }.joined(separator: "\n")
                log("🗑️ \(items.count) Artikel entfernt:\n\(bullets)")
            } else {
                log("🗑️ \(items.count) erledigte Artikel entfernt")
            }
        }

        /// Nicht abgehakte Artikel entfernt
        /// ≤5 → Namen aufführen als Bullet-Liste, >5 → Anzahl
        static func uncheckedItemsDeleted(items: [(name: String, units: Int, measure: String)]) {
            if items.count <= 5 {
                let bullets = items.map { "  • \($0.name)" }.joined(separator: "\n")
                log("🗑️ \(items.count) Artikel entfernt:\n\(bullets)")
            } else {
                log("🗑️ \(items.count) offene Artikel entfernt")
            }
        }

        /// Bulk-Import abgeschlossen — Zusammenfassung (kein Einzel-Spam)
        /// → "📥 Import abgeschlossen:\n  • 12 Artikel hinzugefügt\n  • 5 Artikel zusammengeführt\n  • 3 Mengen erhöht"
        static func bulkImportCompleted(added: Int, reactivated: Int, incremented: Int) {
            var parts: [String] = []
            if added > 0 { parts.append("  • \(added) Artikel hinzugefügt") }
            if reactivated > 0 { parts.append("  • \(reactivated) Artikel zusammengeführt") }
            if incremented > 0 { parts.append("  • \(incremented) Mengen erhöht") }
            guard !parts.isEmpty else { return }
            log("📥 Import abgeschlossen:\n" + parts.joined(separator: "\n"))
        }

        static func itemsLoaded(count: Int, listName: String? = nil) {
            if let listName = listName {
                log("📥 \(count) Artikel für '\(listName)' geladen")
            } else {
                log("📥 \(count) Artikel geladen")
            }
        }

        static func loadingItems(listName: String? = nil) {
            if let listName = listName {
                log("📦 Artikel für '\(listName)' werden geladen...")
            } else {
                log("📦 Artikel werden geladen...")
            }
        }

        static func observingList(listName: String? = nil) {
            if let listName = listName {
                log("👁️ Liste '\(listName)' wird beobachtet...")
            } else {
                log("👁️ Liste wird beobachtet...")
            }
        }

        static func allItemsChecked(count: Int) {
            log("✅ Alle \(count) Artikel als erledigt markiert")
        }

        static func allItemsUnchecked(count: Int) {
            log("⬜️ Alle \(count) Artikel zurückgesetzt")
        }

        static func checkedItemsRemoved(count: Int) {
            log("🗑️ \(count) erledigte Artikel entfernt")
        }

        static func categoriesLoading() {
            log("🏷️ Kategorien werden geladen...")
        }

        static func categoriesLoaded(count: Int) {
            log("✅ \(count) Kategorien geladen")
        }

        static func categoryCreated(name: String) {
            log("➕ Kategorie erstellt: \(name)")
        }

        static func listsLoaded(count: Int) {
            log("📋 \(count) Listen geladen")
        }

        static func listRenamed(oldName: String, newName: String) {
            log("✏️ Liste '\(oldName)' umbenannt zu '\(newName)'")
        }

        static func listDeleted(name: String) {
            log("🗑️ Liste '\(name)' gelöscht")
        }

        static func listSetDefault(name: String) {
            log("⭐ '\(name)' als Standard-Liste gesetzt")
        }
    }

    /// UI-Events
    struct UI {
        static func appLaunched() {
            log("🚀 App gestartet")
        }

        static func mainViewLoaded() {
            log("🏠 Hauptansicht geladen")
        }

        static func viewChanged(to view: String) {
            log("👁️ Wechsel zu \(view)")
        }

        static func loadingImage() {
            log("🖼️ Bild wird geladen...")
        }

        static func imageLoaded() {
            log("✅ Bild geladen")
        }

        static func imageCacheCleared(count: Int) {
            log("🗑️ Bild-Cache geleert (\(count) Bilder)")
        }
    }

    /// Fehler-Events
    struct Error {
        static func general(message: String) {
            log("❌ FEHLER: \(message)")
        }

        static func network(message: String? = nil) {
            if let message = message {
                log("🌐 Netzwerkfehler: \(message)")
            } else {
                log("🌐 Netzwerkfehler: Keine Verbindung zum Server")
            }
        }

        static func database(message: String) {
            log("💾 Datenbankfehler: \(message)")
        }

        static func validation(field: String, message: String) {
            log("⚠️ Eingabefehler bei \(field): \(message)")
        }

        static func unexpected(details: String? = nil) {
            if let details = details {
                log("❗️ Unerwarteter Fehler: \(details)")
            } else {
                log("❗️ Unerwarteter Fehler aufgetreten")
            }
        }
    }

    // MARK: - Hilfsfunktionen

    /// Zentrale Log-Funktion mit Präfix
    private static func log(_ message: String) {
        guard isEnabled else { return }

        let timestamp = DateFormatter.userLogFormatter.string(from: Date())
        let formattedMessage = "\(prefix) [\(timestamp)] \(message)"
        print(formattedMessage)

        // Hinweis: os_log() ist hier bewusst NICHT aktiviert, um Duplikate in der Console zu vermeiden.
        // print() ist für User-Logs völlig ausreichend und erscheint ebenfalls in der Xcode Console.
    }

    static func custom(category: String, message: String) {
        log("[\(category)] \(message)")
    }
}

// MARK: - DateFormatter Extension

private extension DateFormatter {
    static let userLogFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()
}
