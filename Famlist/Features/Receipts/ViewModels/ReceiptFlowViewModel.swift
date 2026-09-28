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
 - Zuschnitt: Findet die Erkennung keinen Bon, bleibt das Foto unverändert. Das Original bleibt in
   `scans` erhalten, ins Archiv und in die Texterkennung geht das zugeschnittene Bild (`pages`).

 - Einkaufsdaten: Uhrzeit und Adresse laut Bon, Zeitpunkt der ersten Aufnahme und Einkaufsbeginn laut Liste
   gehen in den Archiv-Eintrag (ReceiptTimes); die Zeilen bekommen Kategorie, Einheit und Inhalt je Stück
   (ReceiptLineEnricher).

 📝 Last Change:
 - Einkaufsdaten für das Archiv; Preisvergleich nach ReceiptFlowViewModel+PriceChanges ausgelagert.
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

    /// Aufnahmen in Reihenfolge. `image` ist nach dem Zuschnitt der gerade gezogene Bon.
    @Published private(set) var scans: [ReceiptPage] = []
    @Published private(set) var phase: Phase = .capturing
    @Published var lines: [ReceiptReviewLine] = []
    @Published var storeName: String?
    @Published var purchaseDate: Date?
    @Published private(set) var receiptTotal: Decimal?
    /// Uhrzeit und Adresse laut Bon (nur für den Archiv-Eintrag).
    private(set) var receiptTime: DateComponents?
    private(set) var storeAddress: String?
    /// Zeitpunkt der ersten Aufnahme (Ersatz für die Uhrzeit, wenn der Bon keine nennt).
    private(set) var capturedAt: Date?
    @Published var errorMessage: String?
    /// Entscheidungen zu „Nicht auf dem Bon gefunden“, je Artikel-ID.
    @Published private(set) var missingResolutions: [String: ReceiptMissingResolution] = [:]

    /// Abgehakte Artikel der Liste beim Start des Ablaufs (gekauft laut Liste).
    let checkedItems: [ItemModel]

    private(set) var candidates: [String]
    /// Alle Artikel der Liste und die Kategorien des Nutzers: Kategorie und Einheit je Bon-Zeile.
    private let listItems: [ItemModel]
    private let categories: [CategoryDefinition]
    private var catalogEntries: [ItemCatalogEntry] = []
    /// Bekannte Artikelpreise je Name-Schlüssel (CatalogOperation.key): aus der Liste und aus dem Artikelstamm.
    let listPrices: [String: Double]
    private(set) var catalogPrices: [String: Double] = [:]
    private let catalog: (any ItemCatalogRepository)?
    private let priceBook: PriceBook
    private let archive: ReceiptArchive?
    private let origin: ReceiptArchiveOrigin?
    /// Laufende Zuschnitte je Aufnahme. „Prüfen“ wartet, bis alle fertig sind.
    private var cropTasks: [UUID: Task<Void, Never>] = [:]
    /// Ersetzbar in Tests (Vision braucht echte Bilder).
    var recognize: ([UIImage]) async -> [String] = ReceiptTextRecognizer.recognizeLines(in:)
    var cropPage: (UIImage) async -> ReceiptPageCropper.Result = ReceiptPageCropper.autoCrop(_:)
    var cropWithQuad: (UIImage, ReceiptQuad) async -> UIImage? = ReceiptPageCropper.cropInBackground(_:to:)
    var now: () -> Date = Date.init

    /// `listPrices`: Artikelname → Preis der Artikel in der geöffneten Liste.
    /// `checkedItems`: abgehakte Artikel – daraus entsteht „Nicht auf dem Bon gefunden“.
    /// `listItems`/`categories`: für Kategorie und Einheit der Bon-Zeilen im Archiv.
    init(listItemNames: [String], listPrices: [String: Double] = [:], checkedItems: [ItemModel] = [],
         listItems: [ItemModel] = [], categories: [CategoryDefinition] = CategoryDefinition.defaults,
         catalog: (any ItemCatalogRepository)?, priceBook: PriceBook,
         archive: ReceiptArchive? = nil, origin: ReceiptArchiveOrigin? = nil) {
        self.candidates = listItemNames
        self.checkedItems = checkedItems
        self.listItems = listItems
        self.categories = categories
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

    /// Bilder für Texterkennung und Archiv (zugeschnitten, sofern ein Bon erkannt wurde).
    var pages: [UIImage] { scans.map(\.image) }

    // MARK: - Aufnahme

    /// Neue Aufnahme: erscheint sofort als Originalfoto. Der Zuschnitt ersetzt es, sobald er fertig ist.
    /// So bleibt die Reihenfolge erhalten, auch wenn mehrere Zuschnitte gleichzeitig laufen.
    func addPage(_ image: UIImage, automatic: Bool = false) {
        let page = ReceiptPage(original: image)
        if capturedAt == nil { capturedAt = now() }
        scans.append(page)
        if automatic { UserLog.Data.receiptAutoCaptured(page: scans.count) }
        let crop = cropPage
        cropTasks[page.id] = Task { [weak self] in
            let result = await crop(image)
            // Abgebrochen (gelöscht oder von Hand angepasst): Das späte Ergebnis darf nichts überschreiben.
            guard !Task.isCancelled else { return }
            self?.finishCrop(page.id, result: result)
        }
    }

    /// „Ecken anpassen“: neue Ecken übernehmen; nil = „Ganzes Foto“ (Zuschnitt verwerfen).
    func adjustCorners(of id: UUID, to quad: ReceiptQuad?) async {
        guard let index = scans.firstIndex(where: { $0.id == id }) else { return }
        cropTasks.removeValue(forKey: id)?.cancel()
        let original = scans[index].original
        scans[index].isCropping = quad != nil
        let cropped: UIImage? = if let quad { await cropWithQuad(original, quad) } else { nil }
        guard let i = scans.firstIndex(where: { $0.id == id }) else { return }
        scans[i].quad = cropped == nil ? nil : quad
        scans[i].image = cropped ?? original
        scans[i].isCropping = false
        UserLog.Data.receiptCornersAdjusted(page: i + 1, wholePhoto: cropped == nil)
    }

    /// Wartet, bis alle laufenden Zuschnitte fertig sind.
    func finishCropping() async {
        while let task = cropTasks.values.first { await task.value }
    }

    /// Mini-Ansicht: einzelne Aufnahme löschen (✕ am Vorschaubild).
    func removePage(at index: Int) {
        guard scans.indices.contains(index) else { return }
        let removed = scans.remove(at: index)
        cropTasks.removeValue(forKey: removed.id)?.cancel()
        UserLog.Data.receiptPageRemoved(remaining: scans.count)
    }

    /// Ergebnis des Zuschnitts übernehmen; wurde die Aufnahme inzwischen gelöscht, verfällt es.
    private func finishCrop(_ id: UUID, result: ReceiptPageCropper.Result) {
        cropTasks[id] = nil
        guard let index = scans.firstIndex(where: { $0.id == id }) else { return }
        scans[index].quad = result.quad
        scans[index].image = result.image
        scans[index].isCropping = false
    }

    /// „Zurück“ in „Kassenzettel prüfen“: Aufnahmen bleiben, das Erkennungsergebnis wird verworfen
    /// und beim nächsten „Prüfen“ aus allen Aufnahmen neu erstellt.
    func backToCapture() {
        phase = .capturing
        lines = []
        storeName = nil
        purchaseDate = nil
        receiptTotal = nil
        receiptTime = nil
        storeAddress = nil
        errorMessage = nil
    }

    // MARK: - Erkennen

    func process() async {
        guard !scans.isEmpty else { return }
        phase = .recognizing
        await finishCropping()
        if let entries = try? await catalog?.fetchAll() {
            catalogEntries = entries
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
        receiptTime = parsed.time
        storeAddress = parsed.address
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

    // MARK: - Nicht auf dem Bon gefunden (Entscheidungen)

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
    var manualPrices: [(item: ItemModel, price: Decimal)] {
        missingItems.compactMap { item in
            if case .some(.priced(let price)) = missingResolutions[item.id] { return (item, price) }
            return nil
        }
    }

    // MARK: - Speichern

    func savePrices() async {
        let store = (storeName?.isEmpty == false ? storeName : nil) ?? "Unbekannter Laden"
        let date = purchaseDate ?? Date()
        // Die Preise verweisen nur dann auf den Bon, wenn er auch archiviert wird (Schalter an, Liste bekannt).
        let receiptId = UUID()
        let link = archive?.isEnabled == true && origin != nil ? receiptId : nil
        let points = lines.filter(\.isSaved).compactMap { line in
            line.itemName.map { PricePoint(itemName: $0, storeName: store, purchasedAt: date, price: line.unitPrice,
                                           receiptId: link) }
        } + manualPrices.map {
            PricePoint(itemName: $0.item.name, storeName: store, purchasedAt: date, price: $0.price, receiptId: link)
        }
        let saved = await priceBook.save(points)
        await archiveReceipt(id: receiptId, store: store, date: date, savedPrices: saved)
        phase = .done(saved: saved)
    }

    /// Bon mit Aufnahmen und Positionen ins Archiv (nur wenn Schalter an; ReceiptArchive prüft das).
    private func archiveReceipt(id: UUID, store: String, date: Date, savedPrices: Int) async {
        guard let archive, let origin else { return }
        let times = ReceiptTimes.make(day: date, time: receiptTime, capturedAt: capturedAt, listStart: origin.listStart)
        await archive.archive(ReceiptArchiveDraft(
            id: id, pages: pages, listId: origin.listId, listTitle: origin.listTitle, createdBy: origin.createdBy,
            creatorName: origin.creatorName, storeName: store, purchasedAt: date, total: total,
            lineCount: lines.count, savedPriceCount: savedPrices, lines: archivedLines,
            storeAddress: storeAddress, startedAt: times.start, endedAt: times.end))
    }

    /// Positionen für das Archiv, mit Kategorie, Einheit und Inhalt je Stück des zugeordneten Artikels.
    var archivedLines: [ReceiptLine] {
        let enricher = ReceiptLineEnricher(listItems: listItems, catalog: catalogEntries, categories: categories)
        return lines.map { enricher.enrich(ReceiptLine($0)) }
    }
}
