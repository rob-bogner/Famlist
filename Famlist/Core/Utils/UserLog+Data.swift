/*
 UserLog+Data.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Nutzer-Logs der Kategorie UserLog.Data für Artikel: anlegen, abhaken, ändern, löschen, importieren.

 📝 Last Change:
 - Aus UserLogger.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension UserLog {
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

        /// Artikel aus dem Dock gelöscht, 5 s lang rückgängig machbar
        static func itemsDeletedWithUndo(count: Int) {
            log("🗑️ \(count) Artikel gelöscht (Rückgängig möglich)")
        }

        /// Löschung per „Rückgängig“ zurückgenommen
        static func deletionUndone(count: Int) {
            log("↩️ \(count) Artikel wiederhergestellt")
        }

        /// Liste in die Zwischenablage kopiert
        static func listCopied(title: String, count: Int) {
            log("📋 „\(title)“ kopiert (\(count) Artikel)")
        }

        /// Artikel aus dem Artikelstamm gelöscht (Artikel verwalten)
        static func catalogItemDeleted(name: String) {
            log("🗂️ „\(name)“ aus gespeicherten Artikeln entfernt")
        }

        /// Artikel im Artikelstamm geändert (Artikel verwalten)
        static func catalogItemUpdated(name: String) {
            log("🗂️ „\(name)“ gespeichert")
        }

        /// Barcode erkannt und Artikel gefunden
        static func barcodeRecognized(name: String) {
            log("📷 Barcode erkannt: „\(name)“")
        }

        /// Barcode unbekannt → Neuer Artikel
        static func barcodeUnknown(code: String) {
            log("📷 Unbekannter Barcode \(code) – neuer Artikel wird angelegt")
        }

        /// Sortierung der Liste geändert
        static func sortChanged(to order: String) {
            log("↕️ Sortierung: \(order)")
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

        /// Letzter offener Artikel abgehakt → Einkauf erledigt
        static func shoppingCompleted(list: String, count: Int) {
            log("🛒 Einkauf „\(list)“ erledigt – alle \(count) Artikel abgehakt")
        }

        static func allItemsUnchecked(count: Int) {
            log("⬜️ Alle \(count) Artikel zurückgesetzt")
        }

        static func checkedItemsRemoved(count: Int) {
            log("🗑️ \(count) erledigte Artikel entfernt")
        }
    }
}
