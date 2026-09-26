/*
 ReceiptFlowViewModel.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ablauf „Kassenzettel“: Aufnahmen sammeln → Texterkennung → Positionen + Laden + Datum →
   Zuordnung zu Artikeln (korrigierbar) → „Preise speichern“ → „Einkauf erledigt“.

 🔰 Notes for Beginners:
 - Kandidaten für die Zuordnung sind die Artikel der aktuellen Liste und der Artikelstamm.
 - Korrigieren (nicht gestaltet, daher System-Dialog in der Ansicht): anderen Artikel wählen,
   „Als neuen Artikel speichern“ oder „Ignorieren“.
 - Gespeichert werden nur zugeordnete, geprüfte und bestätigte neue Positionen.
 - Preise je Stück: Bei „2 Stk x 1,29“ speichert der Preisverlauf 1,29 €, nicht den Zeilenbetrag 2,58 €.
 - `priceChanges`: zugeordnete Artikel, deren gespeicherter Preis (Liste oder Artikelstamm) vom Bon abweicht.
   „Kassenzettel prüfen“ fragt vor dem Speichern, ob diese Preise die Artikelpreise ersetzen sollen.
 - Kassenzettel-Archiv: „Preise speichern“ legt zusätzlich einen Archiv-Eintrag mit den Aufnahmen an,
   wenn `archive` und `origin` gesetzt sind und der Schalter „Fotos der Bons speichern“ an ist.

 📝 Last Change:
 - „Preise speichern“ legt einen Archiv-Eintrag an (Kassenzettel-Archiv).
 ------------------------------------------------------------------------
 */

import UIKit

@MainActor
final class ReceiptFlowViewModel: ObservableObject {
    enum Phase: Equatable {
        case capturing
        case recognizing
        case review
        case done(saved: Int)
    }

    @Published var pages: [UIImage] = []
    @Published private(set) var phase: Phase = .capturing
    @Published var lines: [ReceiptReviewLine] = []
    @Published var storeName: String?
    @Published var purchaseDate: Date?
    @Published private(set) var receiptTotal: Decimal?
    @Published var errorMessage: String?
    /// Entscheidungen zu „Nicht auf dem Bon gefunden“, je Artikel-ID.
    @Published private(set) var missingResolutions: [String: ReceiptMissingResolution] = [:]

    /// Abgehakte Artikel der Liste beim Start des Ablaufs (gekauft laut Liste).
    let checkedItems: [ItemModel]

    private(set) var candidates: [String]
    /// Bekannte Artikelpreise je Name-Schlüssel (CatalogOperation.key): aus der Liste und aus dem Artikelstamm.
    private let listPrices: [String: Double]
    private var catalogPrices: [String: Double] = [:]
    private let catalog: (any ItemCatalogRepository)?
    private let priceBook: PriceBook
    private let archive: ReceiptArchive?
    private let origin: ReceiptArchiveOrigin?
    /// Ersetzbar in Tests (Vision braucht echte Bilder).
    var recognize: ([UIImage]) async -> [String] = ReceiptTextRecognizer.recognizeLines(in:)

    /// `listPrices`: Artikelname → Preis der Artikel in der geöffneten Liste.
    /// `checkedItems`: abgehakte Artikel – daraus entsteht „Nicht auf dem Bon gefunden“.
    init(listItemNames: [String], listPrices: [String: Double] = [:], checkedItems: [ItemModel] = [],
         catalog: (any ItemCatalogRepository)?, priceBook: PriceBook,
         archive: ReceiptArchive? = nil, origin: ReceiptArchiveOrigin? = nil) {
        self.candidates = listItemNames
        self.checkedItems = checkedItems
        self.listPrices = Dictionary(listPrices.map { (CatalogOperation.key($0.key), $0.value) },
                                     uniquingKeysWith: { first, _ in first })
        self.catalog = catalog
        self.priceBook = priceBook
        self.archive = archive
        self.origin = origin
    }

    /// Summe laut Bon, sonst Summe der Positionen.
    var total: Decimal { receiptTotal ?? lines.filter { !$0.ignored }.reduce(0) { $0 + $1.price } }

    var savableCount: Int { lines.filter(\.isSaved).count + manualPrices.count }

    // MARK: - Aufnahme

    func addPage(_ image: UIImage) { pages.append(image) }

    /// Mini-Ansicht: einzelne Aufnahme löschen (✕ am Vorschaubild).
    func removePage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        pages.remove(at: index)
        UserLog.Data.receiptPageRemoved(remaining: pages.count)
    }

    /// „Zurück“ in „Kassenzettel prüfen“: Aufnahmen bleiben, das Erkennungsergebnis wird verworfen
    /// und beim nächsten „Prüfen“ aus allen Aufnahmen neu erstellt.
    func backToCapture() {
        phase = .capturing
        lines = []
        storeName = nil
        purchaseDate = nil
        receiptTotal = nil
        errorMessage = nil
    }

    // MARK: - Erkennen

    func process() async {
        guard !pages.isEmpty else { return }
        phase = .recognizing
        if let entries = try? await catalog?.fetchAll() {
            candidates = Array(Set(candidates + entries.map(\.name)))
            catalogPrices = Dictionary(entries.map { (CatalogOperation.key($0.name), $0.price) },
                                       uniquingKeysWith: { first, _ in first })
        }
        let text = await recognize(pages)
        apply(ReceiptParser.parse(lines: text))
    }

    /// Ergebnis des Parsers übernehmen und zuordnen.
    func apply(_ parsed: ParsedReceipt) {
        storeName = parsed.store
        purchaseDate = parsed.date
        receiptTotal = parsed.total
        lines = parsed.lines.map { line in
            let match = ReceiptItemMatcher.match(line.raw, candidates: candidates)
            return ReceiptReviewLine(id: line.id, raw: line.raw, price: line.price,
                                     itemName: match.status == .new ? Self.suggestedName(line.raw) : match.candidate,
                                     status: match.status, quantity: line.quantity)
        }
        UserLog.Data.receiptRecognized(lines: lines.count, store: storeName)
        errorMessage = lines.isEmpty ? "Auf dem Kassenzettel wurden keine Positionen erkannt." : nil
        phase = .review
    }

    // MARK: - Korrigieren

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

    /// „Zuordnen“: Bon-Zeile gehört zu diesem Artikel → er gilt als gefunden und verlässt den Abschnitt.
    func assignLine(_ lineId: UUID, to item: ItemModel) {
        assign(lineId, to: item.name)
        missingResolutions[item.id] = nil
        UserLog.Data.receiptMissingAssigned(name: item.name)
    }

    /// „Preis eingeben“: wird beim Speichern wie ein Bon-Preis behandelt.
    func setManualPrice(_ price: Decimal, for item: ItemModel) {
        guard price > 0 else { return }
        missingResolutions[item.id] = .priced(price)
    }

    /// „Nicht gekauft“ (die Liste setzt den Artikel über die View wieder auf offen).
    func markNotBought(_ item: ItemModel) {
        missingResolutions[item.id] = .notBought
        UserLog.Data.receiptItemNotBought(name: item.name)
    }

    /// „Rückgängig“ / „Ändern“: Entscheidung aufheben.
    func clearResolution(for item: ItemModel) {
        missingResolutions[item.id] = nil
    }

    /// Von Hand eingegebene Preise der (noch) nicht gefundenen Artikel.
    private var manualPrices: [(item: ItemModel, price: Decimal)] {
        missingItems.compactMap { item in
            if case .some(.priced(let price)) = missingResolutions[item.id] { return (item, price) }
            return nil
        }
    }

    // MARK: - Speichern

    func savePrices() async {
        let store = (storeName?.isEmpty == false ? storeName : nil) ?? "Unbekannter Laden"
        let date = purchaseDate ?? Date()
        let points = lines.filter(\.isSaved).compactMap { line in
            line.itemName.map { PricePoint(itemName: $0, storeName: store, purchasedAt: date, price: line.unitPrice) }
        } + manualPrices.map { PricePoint(itemName: $0.item.name, storeName: store, purchasedAt: date, price: $0.price) }
        let saved = await priceBook.save(points)
        await archiveReceipt(store: store, date: date, savedPrices: saved)
        phase = .done(saved: saved)
    }

    /// Bon mit Aufnahmen ins Archiv (nur wenn Schalter an; ReceiptArchive prüft das).
    private func archiveReceipt(store: String, date: Date, savedPrices: Int) async {
        guard let archive, let origin else { return }
        await archive.archive(ReceiptArchiveDraft(
            pages: pages, listId: origin.listId, listTitle: origin.listTitle, createdBy: origin.createdBy,
            creatorName: origin.creatorName, storeName: store, purchasedAt: date, total: total,
            lineCount: lines.count, savedPriceCount: savedPrices))
    }

    // MARK: - Artikelpreise

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
