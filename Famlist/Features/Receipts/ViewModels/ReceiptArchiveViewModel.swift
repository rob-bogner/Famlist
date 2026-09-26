/*
 ReceiptArchiveViewModel.swift
 Famlist
 Created on: 26.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Anzeige-Logik für „Kassenzettel“ (Archiv) und das Detail: Filter nach Laden, Gruppen nach Monat,
   Texte wie im Design (ReceiptArchive.dc.html, ReceiptDetail.dc.html).

 🔰 Notes for Beginners:
 - Die Daten kommen aus `ReceiptArchive` (offline zuerst); dieses ViewModel rechnet nur um.
 - Filterchips: „Alle“ + je Laden, in der Reihenfolge des ersten Auftretens (neueste Bons zuerst).
 - Löschen dürfen nur Ersteller und Besitzer der Liste (Migration 021) → `canDelete`.

 📝 Last Change:
 - Initial creation (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import Foundation

@MainActor
final class ReceiptArchiveViewModel: ObservableObject {
    struct MonthGroup: Identifiable, Equatable {
        let id: String
        let title: String
        let receipts: [ArchivedReceipt]
    }

    static let allFilter = "Alle"

    @Published var selectedStore: String = ReceiptArchiveViewModel.allFilter
    let archive: ReceiptArchive
    private let currentUserId: UUID?
    let ownedListIds: Set<UUID>

    init(archive: ReceiptArchive, currentUserId: UUID?, ownedListIds: Set<UUID>) {
        self.archive = archive
        self.currentUserId = currentUserId
        self.ownedListIds = ownedListIds
    }

    // MARK: - Archiv

    /// „12 Bons · 38 MB · für alle in der Liste sichtbar“ (über alle Läden, nicht gefiltert).
    var subtitle: String {
        ReceiptArchiveSetting.summary(count: archive.receipts.count, bytes: archive.totalBytes)
            + " · für alle in der Liste sichtbar"
    }

    var filters: [String] {
        var seen = Set<String>()
        let stores = archive.receipts.map(\.storeName).filter { seen.insert($0.lowercased()).inserted }
        return [Self.allFilter] + stores
    }

    var groups: [MonthGroup] {
        let visible = selectedStore == Self.allFilter
            ? archive.receipts
            : archive.receipts.filter { $0.storeName.caseInsensitiveCompare(selectedStore) == .orderedSame }
        var order: [String] = []
        var byMonth: [String: [ArchivedReceipt]] = [:]
        for receipt in visible {
            let key = Self.monthKey(receipt.purchasedAt)
            if byMonth[key] == nil { order.append(key) }
            byMonth[key, default: []].append(receipt)
        }
        return order.map { MonthGroup(id: $0, title: Self.monthTitle(byMonth[$0]?.first?.purchasedAt ?? Date()),
                                      receipts: byMonth[$0] ?? []) }
    }

    /// Filter zurücksetzen, wenn der gewählte Laden verschwunden ist (z. B. letzter Bon gelöscht).
    func validateFilter() {
        if !filters.contains(selectedStore) { selectedStore = Self.allFilter }
    }

    // MARK: - Zeilen und Detail

    /// „24.09.2026 · Liste Edeka“
    static func dateAndList(_ receipt: ArchivedReceipt) -> String {
        ([day(receipt.purchasedAt)] + [receipt.listTitle].compactMap { $0 }.filter { !$0.isEmpty }).joined(separator: " · ")
    }

    /// „5 Positionen“, bei wartenden Bons „5 Positionen · wird hochgeladen“.
    static func positions(_ receipt: ArchivedReceipt) -> String {
        let text = receipt.lineCount == 1 ? "1 Position" : "\(receipt.lineCount) Positionen"
        return receipt.isPending ? text + " · wird hochgeladen" : text
    }

    /// „24.09.2026 · Liste Edeka · gescannt von Rob“
    static func detailSubtitle(_ receipt: ArchivedReceipt) -> String {
        dateAndList(receipt) + " · gescannt von " + (receipt.creatorName ?? "–")
    }

    /// „5 Positionen · 5 Preise gespeichert“
    static func detailCounts(_ receipt: ArchivedReceipt) -> String {
        let prices = receipt.savedPriceCount == 1 ? "1 Preis gespeichert" : "\(receipt.savedPriceCount) Preise gespeichert"
        return (receipt.lineCount == 1 ? "1 Position" : "\(receipt.lineCount) Positionen") + " · " + prices
    }

    static func euro(_ value: Decimal) -> String {
        value.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
    }

    /// VoiceOver: „Edeka, 24.09.2026 · Liste Edeka, 5 Positionen, 11,51 €“ (aria-label im Design).
    static func accessibilityLabel(_ receipt: ArchivedReceipt) -> String {
        "\(receipt.storeName), \(dateAndList(receipt)), \(positions(receipt)), \(euro(receipt.total))"
    }

    func canDelete(_ receipt: ArchivedReceipt) -> Bool {
        receipt.isPending || (currentUserId != nil && receipt.createdBy == currentUserId) || ownedListIds.contains(receipt.listId)
    }

    // MARK: - Formate

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().locale(Locale(identifier: "de_DE")))
    }

    private static func monthKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    /// „September 2026“ (die Überschrift schreibt es groß).
    static func monthTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "de_DE")))
    }
}
