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
 - Kategorien in UserLog+Auth/+Sync/+Data/+DataLists/+UI/+Error.swift ausgelagert;
   log() und formatQuantity() dafür von private auf internal (Audit 25.09.2026).
 ------------------------------------------------------------------------
*/

import Foundation

/// Benutzerfreundliches Logging-System für Nicht-Entwickler.
/// Ergänzt das technische Developer-Logging mit verständlichen deutschen Nachrichten.
///
/// Grundsatz: Jeder Log enthält Artikelname + Menge + konkreten Aktionstyp.
/// Niemals generische Begriffe wie "aktualisiert" oder "geändert" ohne Kontext.
struct UserLog {

    /// Nur in Debug-Builds an: Die ausgelieferte App schreibt keine Nutzer-Logs in die Systemkonsole
    /// (enthalten Artikel- und Listennamen; Audit 25.09.2026).
    static let isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Eindeutiges Präfix für User-Logs (zum einfachen Filtern).
    private static let prefix = "[👤 USER]"

    // MARK: - Helper

    /// Formatiert eine Mengenangabe nutzerfreundlich.
    /// - `measure=""` → "Nx"  (z. B. "1x")
    /// - sonst → `"N <localizedMeasure>"` (z. B. "3 Stück", "215 ml")
    static func formatQuantity(_ units: Int, _ measure: String) -> String {
        if measure.isEmpty {
            return "\(units)x"
        }
        let localizedMeasure = Measure.fromExternal(measure).localizedName
        return "\(units) \(localizedMeasure)"
    }

    // MARK: - Logging-Kategorien
    // Auth, Sync, Data, UI und Error liegen in UserLog+<Kategorie>.swift.

    // MARK: - Hilfsfunktionen

    /// Zentrale Log-Funktion mit Präfix
    static func log(_ message: String) {
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
