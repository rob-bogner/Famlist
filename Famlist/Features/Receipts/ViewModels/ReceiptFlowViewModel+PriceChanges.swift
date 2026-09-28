/*
 ReceiptFlowViewModel+PriceChanges.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Kassenzettel-Ablauf: Rückfrage „Artikelpreise aktualisieren?“ und Namensvorschlag für neue Artikel.

 🔰 Notes for Beginners:
 - Aus ReceiptFlowViewModel.swift ausgelagert (Datei war über 300 Zeilen); Verhalten unverändert.
 - Vergleicht die Bon-Preise je Stück mit den Preisen der Liste und des Artikelstamms.

 📝 Last Change:
 - Initial creation (ausgelagert aus ReceiptFlowViewModel).
 ------------------------------------------------------------------------
 */

import Foundation

extension ReceiptFlowViewModel {
    /// Zugeordnete Artikel, deren Bon-Preis je Stück vom gespeicherten Artikelpreis abweicht.
    /// Neue Artikel zählen nicht (es gibt keinen Artikel, dessen Preis sich ändern könnte).
    /// Steht ein Artikel mehrmals auf dem Bon, gilt die letzte Position.
    var priceChanges: [ReceiptPriceChange] {
        var latest: [String: ReceiptPriceChange] = [:]
        for line in lines where line.isSaved && line.status != .new && line.unitPrice > 0 {
            guard let name = line.itemName else { continue }
            // Über den Text: NSDecimalNumber.doubleValue macht aus 2,49 den Wert 2,4899999999999998.
            let change = ReceiptPriceChange(name: name, price: Double(line.unitPrice.description) ?? 0)
            latest[change.key] = change
        }
        for manual in manualPrices {
            let change = ReceiptPriceChange(name: manual.item.name, price: Double(manual.price.description) ?? 0)
            latest[change.key] = change
        }
        return latest.values
            .filter { change in
                let known = [listPrices[change.key], catalogPrices[change.key]].compactMap { $0 }
                return !known.isEmpty && known.contains { abs($0 - change.price) > 0.004 }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Text der Rückfrage: bis zu 5 Artikel mit neuem Preis, danach „und n weitere“.
    static func priceChangeMessage(_ changes: [ReceiptPriceChange]) -> String {
        let shown = changes.prefix(5).map { "\($0.name): \(PriceDisplaySetting.euro($0.price))" }
        let more = changes.count > 5 ? ["und \(changes.count - 5) weitere"] : []
        let intro = changes.count == 1
            ? "Bei 1 Artikel weicht der Preis auf dem Kassenzettel vom gespeicherten Preis ab."
            : "Bei \(changes.count) Artikeln weicht der Preis auf dem Kassenzettel vom gespeicherten Preis ab."
        return ([intro, ""] + shown + more).joined(separator: "\n")
    }

    /// „KOKOSM. 400ML“ → „Kokosm. 400ml“ (Vorschlag für einen neuen Artikel).
    static func suggestedName(_ raw: String) -> String {
        raw.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}
