/*
 UserLog+DataLists.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Weitere Nutzer-Logs der Kategorie UserLog.Data: Kategorien, Listen, Mitglieder und Preise.

 📝 Last Change:
 - Aus UserLogger.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension UserLog.Data {
    static func categoriesLoading() {
        UserLog.log("🏷️ Kategorien werden geladen...")
    }

    static func categoriesLoaded(count: Int) {
        UserLog.log("✅ \(count) Kategorien geladen")
    }

    /// Preise aus dem Kassenzettel gespeichert
    static func pricesSaved(count: Int) {
        UserLog.log("🧾 \(count) Preise gespeichert")
    }

    /// Preise vom Kassenzettel als neue Artikelpreise übernommen
    static func itemPricesUpdated(count: Int) {
        UserLog.log("🧾 \(count == 1 ? "1 Artikelpreis" : "\(count) Artikelpreise") vom Kassenzettel übernommen")
    }

    /// Kassenzettel erkannt
    static func receiptRecognized(lines: Int, store: String?) {
        UserLog.log("🧾 Kassenzettel erkannt: \(lines) Positionen\(store.map { " bei \($0)" } ?? "")")
    }

    /// Kategorie umbenannt / Icon geändert
    static func categoryUpdated(name: String) {
        UserLog.log("🏷️ Kategorie „\(name)“ gespeichert")
    }

    /// Kategorie gelöscht (Artikel wandern nach „Sonstiges“)
    static func categoryDeleted(name: String) {
        UserLog.log("🏷️ Kategorie „\(name)“ gelöscht – Artikel stehen jetzt unter „Sonstiges“")
    }

    static func categoryCreated(name: String) {
        UserLog.log("➕ Kategorie erstellt: \(name)")
    }

    static func listsLoaded(count: Int) {
        UserLog.log("📋 \(count) Listen geladen")
    }

    static func listRenamed(oldName: String, newName: String) {
        UserLog.log("✏️ Liste '\(oldName)' umbenannt zu '\(newName)'")
    }

    /// Mitglied aus einer Liste entfernt
    static func memberRemoved(name: String) {
        UserLog.log("👥 \(name) aus der Liste entfernt")
    }

    /// Einladungslink kopiert
    static func inviteLinkCopied(listName: String) {
        UserLog.log("🔗 Einladungslink für „\(listName)“ kopiert")
    }

    /// Geteilte Liste verlassen
    static func listLeft(name: String) {
        UserLog.log("🚪 Liste „\(name)“ verlassen")
    }

    static func listDeleted(name: String) {
        UserLog.log("🗑️ Liste '\(name)' gelöscht")
    }

    static func listSetDefault(name: String) {
        UserLog.log("⭐ '\(name)' als Standard-Liste gesetzt")
    }

    /// Liste dupliziert
    static func listDuplicated(name: String, newName: String, itemCount: Int) {
        UserLog.log("📑 Liste '\(name)' dupliziert als '\(newName)' (\(itemCount) Artikel)")
    }

    /// Artikel als „nicht verfügbar“ markiert oder wieder verfügbar gemacht
    static func itemAvailabilityChanged(name: String, isUnavailable: Bool) {
        UserLog.log(isUnavailable ? "🚫 Nicht verfügbar: \(name)" : "↩️ Wieder verfügbar: \(name)")
    }

    /// Alle Artikel einer Kategorie abgehakt
    static func categoryItemsChecked(category: String, count: Int) {
        UserLog.log("☑️ \(count) Artikel in '\(category)' abgehakt")
    }

    static func listJoined() {
        UserLog.log("🤝 Geteilter Liste beigetreten")
    }

    static func accessRevoked() {
        UserLog.log("🚫 Zugriff auf geteilte Liste wurde entzogen")
    }
}
