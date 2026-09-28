/*
 ReceiptDetailFormat.swift
 Famlist
 Created on: 29.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Inhalt des Bon-Details (Board ReceiptDetailMeta): sechs Kacheln mit Einkaufsdaten und die Artikelzeilen.

 🔰 Notes for Beginners:
 - Ort: Laden + Adresse · Datum: „Do, 24.09.“ + Jahr · Uhrzeit: Beginn (sonst Ende) + „bis <Ende>“ ·
   Dauer: „23 min“ + „laut Liste“ (nur mit Beginn und Ende) · Artikel: „<Positionen> · <Stück> Stück“ +
   „<n> Mehrfachkauf/-käufe“ · Wert: Summe + „Ø <Betrag> je Stück“.
 - Bons ohne gespeicherte Zeilen (vor Migration 029): „<n> Positionen“, Stückzahl unbekannt → keine Unterzeilen.
 - Zeile: „<Anzahl> × <Inhalt je Stück> · je <Einzelpreis>“; ohne bekannten Inhalt „<Anzahl> Stück · je …“.
 - Reine Funktionen → Unit-Tests (ReceiptDetailFormatTests).

 📝 Last Change:
 - Initial creation (Einkaufsdaten & Auswertung).
 ------------------------------------------------------------------------
 */

import Foundation

enum ReceiptDetailFormat {
    /// „Liste Edeka · gescannt von Rob“ (das Datum steht jetzt in den Kacheln).
    static func subtitle(_ receipt: ArchivedReceipt) -> String {
        let scanner = "gescannt von " + (receipt.creatorName ?? "–")
        return receipt.listTitle.map { "\($0) · \(scanner)" } ?? scanner
    }

    // MARK: - Kacheln

    static func tiles(_ receipt: ArchivedReceipt, lines: [ReceiptLine]?) -> [ReceiptMetaTile] {
        [store(receipt), date(receipt), time(receipt), duration(receipt), items(receipt, lines), value(receipt, lines)]
    }

    private static func store(_ r: ArchivedReceipt) -> ReceiptMetaTile {
        ReceiptMetaTile(kind: .store, value: r.storeName, sub: r.storeAddress)
    }

    private static func date(_ r: ArchivedReceipt) -> ReceiptMetaTile {
        ReceiptMetaTile(kind: .date, value: InsightFormat.weekdayDay(r.purchasedAt), sub: InsightFormat.year(r.purchasedAt))
    }

    private static func time(_ r: ArchivedReceipt) -> ReceiptMetaTile {
        guard let first = r.startedAt ?? r.endedAt else { return .unknown(.time) }
        let until = r.startedAt != nil ? r.endedAt.map { "bis \(InsightFormat.clock($0))" } : nil
        return ReceiptMetaTile(kind: .time, value: InsightFormat.clock(first), sub: until)
    }

    private static func duration(_ r: ArchivedReceipt) -> ReceiptMetaTile {
        guard let minutes = durationMinutes(r) else { return .unknown(.duration) }
        return ReceiptMetaTile(kind: .duration, value: "\(minutes) min", sub: "laut Liste")
    }

    /// Minuten zwischen Beginn und Ende (gerundet); nil, wenn eines fehlt.
    static func durationMinutes(_ r: ArchivedReceipt) -> Int? {
        guard let start = r.startedAt, let end = r.endedAt, end >= start else { return nil }
        return Int((end.timeIntervalSince(start) / 60).rounded())
    }

    private static func items(_ r: ArchivedReceipt, _ lines: [ReceiptLine]?) -> ReceiptMetaTile {
        guard let lines, !lines.isEmpty else {
            return ReceiptMetaTile(kind: .items, value: r.lineCount == 1 ? "1 Position" : "\(r.lineCount) Positionen", sub: nil)
        }
        let multi = lines.filter { $0.quantity > 1 }.count
        return ReceiptMetaTile(kind: .items, value: "\(lines.count) · \(pieces(lines)) Stück",
                               sub: multi == 1 ? "1 Mehrfachkauf" : "\(multi) Mehrfachkäufe")
    }

    private static func value(_ r: ArchivedReceipt, _ lines: [ReceiptLine]?) -> ReceiptMetaTile {
        let count = lines.map(pieces) ?? 0
        let average = count > 0 ? "Ø \(InsightFormat.euro(rounded(r.total / Decimal(count)))) je Stück" : nil
        return ReceiptMetaTile(kind: .value, value: InsightFormat.euro(r.total), sub: average)
    }

    static func pieces(_ lines: [ReceiptLine]) -> Int {
        lines.reduce(0) { $0 + max($1.quantity, 1) }
    }

    static func rounded(_ value: Decimal) -> Decimal {
        var exact = value
        var result = Decimal()
        NSDecimalRound(&result, &exact, 2, .plain)
        return result
    }

    // MARK: - Zeilen

    static func rows(_ lines: [ReceiptLine], context: ReceiptLineContext) -> [ReceiptLineDisplay] {
        lines.enumerated().map { index, line in
            let definition = context.definition(named: line.category)
            return ReceiptLineDisplay(id: index, name: line.itemName ?? line.raw, detail: detail(line),
                                      categoryName: line.category ?? ReceiptLineDisplay.noCategory,
                                      category: definition, rank: context.ranking.rank(of: line.category),
                                      amount: InsightFormat.euro(line.price), itemName: line.itemName)
        }
    }

    /// „1 × 250 g · je 2,49 €“
    static func detail(_ line: ReceiptLine) -> String {
        let count = max(line.quantity, 1)
        let each = "je \(InsightFormat.euro(line.unitPrice))"
        guard let units = line.units, units > 0 else { return "\(count) Stück · \(each)" }
        return "\(count) × \(InsightFormat.amount(units, measure: line.measure)) · \(each)"
    }
}
