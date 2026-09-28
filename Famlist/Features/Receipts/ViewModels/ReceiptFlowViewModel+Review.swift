/*
 ReceiptFlowViewModel+Review.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kassenzettel-Ablauf, Schritt „Kassenzettel prüfen“: Zeilen zuordnen, als neu bestätigen, ignorieren;
   Abfragen für „Nicht auf dem Bon gefunden“.

 🔰 Notes for Beginners:
 - Aus ReceiptFlowViewModel.swift ausgelagert (Datei war über 300 Zeilen); Verhalten unverändert.
 - Entscheidungen zu fehlenden Artikeln (Preis eingeben, nicht gekauft) bleiben im Haupttyp,
   weil sie dessen geschützten Zustand ändern.

 📝 Last Change:
 - Initial creation (ausgelagert aus ReceiptFlowViewModel).
 ------------------------------------------------------------------------
 */

import Foundation

extension ReceiptFlowViewModel {
    func suggestions(for line: ReceiptReviewLine) -> [String] {
        ReceiptItemMatcher.suggestions(line.raw, candidates: candidates)
    }

    func assign(_ lineId: UUID, to name: String) {
        guard let i = lines.firstIndex(where: { $0.id == lineId }) else { return }
        lines[i].itemName = name
        lines[i].status = .matched
        lines[i].ignored = false
    }

    func confirmNew(_ lineId: UUID) {
        guard let i = lines.firstIndex(where: { $0.id == lineId }) else { return }
        lines[i].confirmedNew = true
        lines[i].ignored = false
    }

    func ignore(_ lineId: UUID) {
        guard let i = lines.firstIndex(where: { $0.id == lineId }) else { return }
        lines[i].ignored = true
    }

    // MARK: - Nicht auf dem Bon gefunden

    /// Abgehakte Artikel, zu denen keine Bon-Zeile gehört (zugeordnet oder „prüfen“; ignorierte zählen nicht).
    var missingItems: [ItemModel] {
        let found = Set(lines.filter { !$0.ignored && ($0.status != .new || $0.confirmedNew) }
            .compactMap { $0.itemName.map(CatalogOperation.key) })
        return checkedItems.filter { !found.contains(CatalogOperation.key($0.name)) }
    }

    /// Bon-Zeilen ohne Artikel („Neuer Artikel?“, weder bestätigt noch ignoriert).
    var unassignedLines: [ReceiptReviewLine] {
        lines.filter { $0.status == .new && !$0.confirmedNew && !$0.ignored }
    }

    /// Vorschläge für „Zuordnen“: freie Bon-Zeilen, die ähnlichste zuerst.
    func lineSuggestions(for item: ItemModel) -> [ReceiptReviewLine] {
        unassignedLines.sorted { ReceiptItemMatcher.score($0.raw, item.name) > ReceiptItemMatcher.score($1.raw, item.name) }
    }
}
