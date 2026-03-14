/*
 UserLogger.swift
 
 Famlist
 Created on: 23.11.2025
 Last updated on: 23.11.2025
 
 ------------------------------------------------------------------------
 📄 File Overview:
 - Benutzerfreundliches Logging-System für Nicht-Entwickler.
 - Ergänzt das technische Developer-Logging mit verständlichen Nachrichten.
 
 🛠 Includes:
 - UserLog struct mit Kategorien (Auth, Sync, Daten, UI, Fehler)
 - Eindeutiges Präfix [👤 USER] zum einfachen Filtern
 - Deutsche, sprechende Nachrichten
 
 🔰 Notes for Beginners:
 - Verwenden Sie UserLog.auth(), UserLog.sync(), etc. für benutzerfreundliche Logs
 - Logs können über UserLog.isEnabled global an/ausgeschaltet werden
 - Filter-Tipp: Suche nach "[👤 USER]" um nur User-Logs zu sehen
 
 📝 Last Change:
 - Initial creation für benutzerfreundliches Logging-System.
 ------------------------------------------------------------------------
*/

import Foundation

/// Benutzerfreundliches Logging-System für Nicht-Entwickler.
/// Ergänzt das technische Developer-Logging mit verständlichen deutschen Nachrichten.
struct UserLog {
    
    /// Globaler Schalter für User-Logging (standardmäßig aktiviert).
    /// Setzen Sie auf `false`, um User-Logs zu deaktivieren.
    static var isEnabled: Bool = true
    
    /// Eindeutiges Präfix für User-Logs (zum einfachen Filtern).
    private static let prefix = "[👤 USER]"
    
    // MARK: - Logging-Kategorien
    
    /// Authentifizierungs- und Profil-Events
    struct Auth {
        /// Benutzer meldet sich an
        static func loginStarted(email: String? = nil) {
            if let email = email {
                log("🔑 Anmeldung gestartet für \(email)")
            } else {
                log("🔑 Anmeldung gestartet")
            }
        }
        
        /// Benutzer erfolgreich angemeldet
        static func loginSuccess(username: String? = nil) {
            if let username = username {
                log("✅ Erfolgreich angemeldet als \(username)")
            } else {
                log("✅ Erfolgreich angemeldet")
            }
        }
        
        /// Anmeldung fehlgeschlagen
        static func loginFailed(reason: String? = nil) {
            if let reason = reason {
                log("❌ Anmeldung fehlgeschlagen: \(reason)")
            } else {
                log("❌ Anmeldung fehlgeschlagen")
            }
        }
        
        /// Benutzer abgemeldet
        static func loggedOut() {
            log("👋 Benutzer abgemeldet")
        }
        
        /// Session wird wiederhergestellt
        static func restoringSession() {
            log("🔄 Sitzung wird wiederhergestellt...")
        }
        
        /// Session erfolgreich wiederhergestellt
        static func sessionRestored() {
            log("✅ Sitzung wiederhergestellt")
        }
        
        /// Profil wird geladen
        static func loadingProfile() {
            log("👤 Benutzerprofil wird geladen...")
        }
        
        /// Profil geladen
        static func profileLoaded(publicId: String? = nil) {
            if let publicId = publicId {
                log("✅ Benutzerprofil geladen (ID: \(publicId))")
            } else {
                log("✅ Benutzerprofil geladen")
            }
        }
        
        /// Auth-Session bereit
        static func authSessionReady() {
            log("🔐 Authentifizierung bereit")
        }
        
        /// Auth-Status geändert
        static func authStateChanged(event: String) {
            log("🔄 Auth-Status: \(event)")
        }
        
        /// Auth-Bootstrap abgeschlossen
        static func authBootstrapCompleted() {
            log("✅ Initialisierung abgeschlossen")
        }
    }
    
    /// Synchronisierungs-Events
    struct Sync {
        /// Synchronisierung gestartet
        static func started() {
            log("🔄 Synchronisierung gestartet")
        }
        
        /// Daten werden mit Server synchronisiert
        static func syncing(itemCount: Int) {
            log("☁️ Synchronisiere \(itemCount) Artikel mit Server...")
        }
        
        /// Synchronisierung erfolgreich
        static func completed(itemCount: Int? = nil) {
            if let count = itemCount {
                log("✅ Synchronisierung abgeschlossen (\(count) Artikel)")
            } else {
                log("✅ Synchronisierung abgeschlossen")
            }
        }
        
        /// Synchronisierung fehlgeschlagen
        static func failed(reason: String? = nil) {
            if let reason = reason {
                log("⚠️ Synchronisierung fehlgeschlagen: \(reason)")
            } else {
                log("⚠️ Synchronisierung fehlgeschlagen")
            }
        }
        
        /// Echtzeit-Update empfangen
        static func realtimeUpdate(itemName: String? = nil) {
            if let itemName = itemName {
                log("📡 Echtzeit-Update empfangen für '\(itemName)'")
            } else {
                log("📡 Echtzeit-Update empfangen")
            }
        }
        
        /// Offline-Modus aktiviert
        static func offlineMode() {
            log("📴 Offline-Modus: Änderungen werden lokal gespeichert")
        }
        
        /// Online-Modus wiederhergestellt
        static func onlineMode() {
            log("📶 Verbindung wiederhergestellt - Synchronisierung läuft")
        }
        
        /// Echtzeit-Updates werden eingerichtet
        static func realtimeStarted(listName: String? = nil) {
            if let listName = listName {
                log("📡 Echtzeit-Updates für '\(listName)' werden eingerichtet...")
            } else {
                log("📡 Echtzeit-Updates werden eingerichtet...")
            }
        }
        
        /// Operation in Warteschlange eingereiht
        static func operationEnqueued() {
            log("⏳ Operation in Warteschlange eingereiht")
        }
        
        /// Operation wird in Warteschlange eingereiht
        static func operationQueued(type: String, itemName: String? = nil) {
            if let itemName = itemName {
                log("📝 \(type)-Operation für '\(itemName)' in Warteschlange")
            } else {
                log("📝 \(type)-Operation in Warteschlange")
            }
        }
        
        /// Operation wird verarbeitet
        static func processingOperation(type: String, itemName: String? = nil) {
            if let itemName = itemName {
                log("⚙️ Verarbeite \(type) für '\(itemName)'...")
            } else {
                log("⚙️ Verarbeite \(type)-Operation...")
            }
        }
        
        /// Operation erfolgreich abgeschlossen
        static func operationCompleted(type: String, itemName: String? = nil) {
            if let itemName = itemName {
                log("✅ \(type) für '\(itemName)' abgeschlossen")
            } else {
                log("✅ \(type)-Operation abgeschlossen")
            }
        }
        
        /// Operation aus Warteschlange entfernt
        static func operationRemoved() {
            log("🗑️ Operation aus Warteschlange entfernt")
        }
        
        /// Echtzeit-Update empfangen und verarbeitet
        static func realtimeUpdateReceived(name: String) {
            log("📡 Artikel '\(name)' wurde remote aktualisiert")
        }
        
        /// Echtzeit-Löschung empfangen
        static func realtimeDeleteReceived(name: String? = nil) {
            if let name = name {
                log("📡 Artikel '\(name)' wurde remote gelöscht")
            } else {
                log("📡 Artikel wurde remote gelöscht")
            }
        }
        
        /// Supabase-Client initialisiert
        static func supabaseInitialized(host: String) {
            log("🔌 Verbindung zu Supabase-Server (\(host)) wird hergestellt...")
        }
        
        /// Echtzeit-Kanal erfolgreich verbunden
        static func realtimeChannelConnected(listName: String? = nil) {
            if let listName = listName {
                log("✅ Echtzeit-Verbindung für '\(listName)' hergestellt")
            } else {
                log("✅ Echtzeit-Verbindung hergestellt")
            }
        }
        
        /// Echtzeit-Kanal pausiert (App im Hintergrund)
        static func realtimePaused(listName: String? = nil) {
            if let listName = listName {
                log("⏸️ Echtzeit-Updates für '\(listName)' pausiert (App im Hintergrund)")
            } else {
                log("⏸️ Echtzeit-Updates pausiert (App im Hintergrund)")
            }
        }
        
        /// Echtzeit-Kanal getrennt
        static func realtimeDisconnected(listName: String? = nil) {
            if let listName = listName {
                log("📴 Echtzeit-Verbindung für '\(listName)' getrennt")
            } else {
                log("📴 Echtzeit-Verbindung getrennt")
            }
        }
        
        /// Echtzeit-Kanal fortgesetzt (App im Vordergrund)
        static func realtimeResumed(listName: String? = nil) {
            if let listName = listName {
                log("▶️ Echtzeit-Updates für '\(listName)' fortgesetzt")
            } else {
                log("▶️ Echtzeit-Updates fortgesetzt")
            }
        }
    }
    
    /// Daten-Events (Listen, Artikel)
    struct Data {
        /// Liste wird geladen
        static func loadingList(name: String? = nil) {
            if let name = name {
                log("📋 Liste '\(name)' wird geladen...")
            } else {
                log("📋 Liste wird geladen...")
            }
        }
        
        /// Liste geladen
        static func listLoaded(name: String, itemCount: Int) {
            log("✅ Liste '\(name)' geladen (\(itemCount) Artikel)")
        }
        
        /// Liste erstellt
        static func listCreated(name: String) {
            log("➕ Liste erstellt: \(name)")
        }
        
        /// Artikel hinzugefügt
        static func itemAdded(name: String, units: Int? = nil, measure: String? = nil) {
            if let units = units, let measure = measure, !measure.isEmpty {
                log("➕ Artikel hinzugefügt: \(name) (\(units) \(measure))")
            } else if let units = units {
                log("➕ Artikel hinzugefügt: \(name) (\(units)x)")
            } else {
                log("➕ Artikel hinzugefügt: \(name)")
            }
        }
        
        /// Artikel bereits vorhanden – Anzahl erhöht
        static func itemCountIncremented(name: String, units: Int) {
            log("➕ '\(name)' bereits in der Liste – Anzahl auf \(units) erhöht")
        }

        /// Artikel aktualisiert
        static func itemUpdated(name: String, units: Int? = nil, measure: String? = nil) {
            if let units = units, let measure = measure, !measure.isEmpty {
                log("✏️ Artikel aktualisiert: \(name) (\(units) \(measure))")
            } else if let units = units {
                log("✏️ Artikel aktualisiert: \(name) (\(units)x)")
            } else {
                log("✏️ Artikel aktualisiert: \(name)")
            }
        }
        
        /// Artikel gelöscht
        static func itemDeleted(name: String? = nil) {
            if let name = name {
                log("🗑️ Artikel gelöscht: \(name)")
            } else {
                log("🗑️ Artikel gelöscht")
            }
        }
        
        /// Alle Artikel der Liste gelöscht
        static func allItemsDeleted(count: Int) {
            log("🗑️ \(count) Artikel gelöscht")
        }

        /// Nur abgehakte Artikel gelöscht
        static func checkedItemsDeleted(count: Int) {
            log("🗑️ \(count) erledigte Artikel gelöscht")
        }

        /// Nur nicht abgehakte Artikel gelöscht
        static func uncheckedItemsDeleted(count: Int) {
            log("🗑️ \(count) offene Artikel gelöscht")
        }

        /// Mehrere Artikel werden aktualisiert
        static func bulkUpdate(count: Int) {
            log("💾 \(count) Artikel werden aktualisiert...")
        }
        
        /// Artikel geladen
        static func itemsLoaded(count: Int, listName: String? = nil) {
            if let listName = listName {
                log("📥 \(count) Artikel für '\(listName)' geladen")
            } else {
                log("📥 \(count) Artikel geladen")
            }
        }
        
        /// Artikel werden geladen
        static func loadingItems(listName: String? = nil) {
            if let listName = listName {
                log("📦 Artikel für '\(listName)' werden geladen...")
            } else {
                log("📦 Artikel werden geladen...")
            }
        }
        
        /// Liste wird beobachtet
        static func observingList(listName: String? = nil) {
            if let listName = listName {
                log("👁️ Liste '\(listName)' wird beobachtet...")
            } else {
                log("👁️ Liste wird beobachtet...")
            }
        }
        
        /// Alle Artikel abgehakt
        static func allItemsChecked(count: Int) {
            log("✅ Alle \(count) Artikel als erledigt markiert")
        }
        
        /// Alle Artikel zurückgesetzt
        static func allItemsUnchecked(count: Int) {
            log("⬜️ Alle \(count) Artikel zurückgesetzt")
        }
        
        /// Erledigte Artikel entfernt
        static func checkedItemsRemoved(count: Int) {
            log("🗑️ \(count) erledigte Artikel entfernt")
        }
        
        /// Artikel aus Zwischenablage importiert
        static func clipboardImport(count: Int) {
            log("📋 \(count) Artikel aus Zwischenablage importiert")
        }
        
        /// Artikel lokal gespeichert
        static func itemStoredLocally(name: String) {
            log("💾 Lokal gespeichert: \(name)")
        }
        
        /// Artikel lokal als gelöscht markiert
        static func itemDeletedLocally() {
            log("💾 Lokal als gelöscht markiert")
        }
        
        /// Kategorien werden geladen
        static func categoriesLoading() {
            log("🏷️ Kategorien werden geladen...")
        }
        
        /// Kategorien geladen
        static func categoriesLoaded(count: Int) {
            log("✅ \(count) Kategorien geladen")
        }
        
        /// Kategorie erstellt
        static func categoryCreated(name: String) {
            log("➕ Kategorie erstellt: \(name)")
        }

        /// Alle Listen geladen
        static func listsLoaded(count: Int) {
            log("📋 \(count) Listen geladen")
        }

        /// Liste umbenannt
        static func listRenamed(oldName: String, newName: String) {
            log("✏️ Liste '\(oldName)' umbenannt zu '\(newName)'")
        }

        /// Liste gelöscht
        static func listDeleted(name: String) {
            log("🗑️ Liste '\(name)' gelöscht")
        }

        /// Standard-Liste gesetzt
        static func listSetDefault(name: String) {
            log("⭐ '\(name)' als Standard-Liste gesetzt")
        }
    }
    
    /// UI-Events
    struct UI {
        /// App gestartet
        static func appLaunched() {
            log("🚀 App gestartet")
        }
        
        /// Hauptansicht geladen
        static func mainViewLoaded() {
            log("🏠 Hauptansicht geladen")
        }
        
        /// Ansicht gewechselt
        static func viewChanged(to view: String) {
            log("👁️ Wechsel zu \(view)")
        }
        
        /// Bild wird geladen
        static func loadingImage() {
            log("🖼️ Bild wird geladen...")
        }
        
        /// Bild geladen
        static func imageLoaded() {
            log("✅ Bild geladen")
        }
        
        /// Bild-Cache geleert
        static func imageCacheCleared(count: Int) {
            log("🗑️ Bild-Cache geleert (\(count) Bilder)")
        }
    }
    
    /// Fehler-Events
    struct Error {
        /// Allgemeiner Fehler
        static func general(message: String) {
            log("❌ FEHLER: \(message)")
        }
        
        /// Netzwerkfehler
        static func network(message: String? = nil) {
            if let message = message {
                log("🌐 Netzwerkfehler: \(message)")
            } else {
                log("🌐 Netzwerkfehler: Keine Verbindung zum Server")
            }
        }
        
        /// Datenbankfehler
        static func database(message: String) {
            log("💾 Datenbankfehler: \(message)")
        }
        
        /// Validierungsfehler
        static func validation(field: String, message: String) {
            log("⚠️ Eingabefehler bei \(field): \(message)")
        }
        
        /// Unerwarteter Fehler
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
    
    /// Benutzerdefinierte Nachricht loggen
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

