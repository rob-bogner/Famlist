/*
 ProductPhotoMatcher.swift
 Famlist
 Created on: 01.10.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Per Foto hinzufügen“: Welches Katalogprodukt zeigt das Foto? Bewertet Kandidaten aus dem globalen Katalog
   streng gegen die gelesene Aufschrift und das Foto und entscheidet: sicher übernehmen, nachfragen oder keiner.

 🔰 Notes for Beginners:
 - Grundsatz: Was auf der Packung steht, zählt. Der Katalog ergänzt nur, wenn er sicher passt.
 - Text: nur ganze Wörter. „Butter“ passt NICHT zu „Erdnussbutter“ – „Erdnuss“ steht nicht auf der Packung.
   Zusammengesetzte Wörter zählen, wenn alle Teile auf der Packung stehen („Süßrahm“ + „Butter“ = „Süßrahmbutter“).
   Kleine Lesefehler (ein Buchstabe ab 5 Zeichen) sind erlaubt.
 - Bild: Vision-Merkmale (VNGenerateImageFeaturePrintRequest) von Foto und Katalogbild; ähnlich = Pluspunkt.
 - Entscheidung: ≥ 0,8 und klar vor dem Zweiten → sicher; ≥ 0,45 → „Welcher ist es?“ (bis zu 3); sonst keiner.
 - Barcode-Treffer entscheidet der Aufrufer vorher (immer sicher).

 📝 Last Change:
 - Initial creation (Foto von „Rewe Bio Süßrahm Butter“ wurde zu „Erdnussbutter Creamy“, 01.10.2026).
 ------------------------------------------------------------------------
 */

import Foundation
import UIKit
import Vision

/// Ein bewerteter Kandidat.
struct ProductMatchCandidate: Identifiable, Sendable, Equatable {
    let product: GlobalProductEntry
    var textScore: Double
    var visualScore: Double?
    var score: Double
    var id: String { product.id }
}

enum ProductPhotoMatchResult: Sendable, Equatable {
    case certain(ProductMatchCandidate)
    case choose([ProductMatchCandidate])
    case none
}

enum ProductPhotoMatcher {
    // MARK: - Schwellen

    static let certainScore = 0.8
    static let certainMargin = 0.12
    static let suggestScore = 0.45

    // MARK: - Wörter von der Packung

    struct Keyword: Sendable, Equatable {
        /// So wie gelesen (klein), für die Datenbanksuche.
        let raw: String
        /// Vereinheitlicht (ß → ss, ohne Akzente), für den Vergleich.
        let folded: String
        /// 0…1: Schriftgröße relativ zur größten Zeile.
        let weight: Double
    }

    /// Aufdrucke, die auf vielen Packungen stehen und nichts über das Produkt sagen.
    static let noise: Set<String> = [
        "und", "mit", "aus", "von", "der", "die", "das", "den", "dem", "des", "fur", "fuer", "ohne", "nach", "art",
        "vom", "zum", "zur", "ein", "eine", "the", "and", "for", "with", "nutri", "score", "nutriscore",
        "haltungsform", "haltungs", "form", "www", "com", "net", "inhalt", "enthalt", "enthaelt", "mindestens", "haltbar", "bis",
        "zutaten", "naehrwerte", "nahrwerte", "pro", "neu", "new", "packung", "stuck", "stueck", "ca",
    ]

    static func fold(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "ß", with: "ss")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
    }

    /// Wörter eines Textes (Buchstaben und Ziffern), klein.
    static func words(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Wörter von der Packung, gewichtet nach Schriftgröße; erkannte Felder (Name, Marke, Sorte) zählen voll.
    static func keywords(reading: ProductPhotoReading, fields: ProductPhotoFields?) -> [Keyword] {
        let maxHeight = reading.lines.map(\.box.height).max() ?? 1
        var best: [String: Keyword] = [:]
        func add(_ text: String, weight: Double) {
            for w in words(text) where w.count >= 3 && w.rangeOfCharacter(from: .letters) != nil {
                let folded = fold(w)
                guard !noise.contains(folded) else { continue }
                if (best[folded]?.weight ?? -1) < weight { best[folded] = Keyword(raw: w, folded: folded, weight: weight) }
            }
        }
        for line in reading.lines { add(line.text, weight: min(1, Double(line.box.height / max(maxHeight, 0.0001)))) }
        if let fields {
            add(fields.name, weight: 1)
            if let brand = fields.brand { add(brand, weight: 0.9) }
            if let variant = fields.variant { add(variant, weight: 0.8) }
        }
        return best.values.sorted { $0.weight != $1.weight ? $0.weight > $1.weight : $0.folded < $1.folded }
    }

    /// Suchwörter für die Datenbank: die größten, höchstens 8.
    static func queryWords(_ keywords: [Keyword]) -> [String] {
        Array(keywords.filter { $0.weight >= 0.2 }.prefix(8).map(\.raw))
    }

    // MARK: - Text bewerten

    /// 0…1: Wie gut passt Name + Marke des Kandidaten zur Aufschrift?
    /// - Treffer: große Wörter der Packung, die im Kandidaten vorkommen (gewichtet nach Schriftgröße).
    /// - Genauigkeit: Anteil der Kandidaten-Wörter (nach Länge), die auf der Packung stehen.
    static func textScore(_ product: GlobalProductEntry, keywords: [Keyword]) -> Double {
        let vocabulary = Set(keywords.map(\.folded))
        let tokens = words(product.name + " " + (product.brand ?? "")).map(fold)
        guard !tokens.isEmpty, !keywords.isEmpty else { return 0 }

        var explainedLength = 0.0
        var totalLength = 0.0
        var covered = Set<String>()
        for token in tokens {
            if token.count <= 2 || token.allSatisfy(\.isNumber) || isQuantityToken(token) || noise.contains(token) { continue }
            totalLength += Double(token.count)
            if let parts = explain(token, vocabulary: vocabulary) {
                explainedLength += Double(token.count)
                covered.formUnion(parts)
            }
        }
        let precision = totalLength > 0 ? explainedLength / totalLength : 0

        let important = keywords.filter { $0.weight >= 0.45 }
        let importantWeight = important.reduce(0) { $0 + $1.weight }
        let foundWeight = important.filter { covered.contains($0.folded) }.reduce(0) { $0 + $1.weight }
        let recall = importantWeight > 0 ? foundWeight / importantWeight : 0

        return 0.55 * recall + 0.45 * precision
    }

    /// Welche Packungswörter erklären das Kandidaten-Wort? Ganzes Wort (ein Lesefehler ab 5 Zeichen erlaubt)
    /// oder zusammengesetzt aus Packungswörtern (je ab 3 Zeichen). nil = steht nicht auf der Packung.
    static func explain(_ token: String, vocabulary: Set<String>) -> [String]? {
        if vocabulary.contains(token) { return [token] }
        if token.count >= 5, let near = vocabulary.first(where: { $0.count >= 5 && abs($0.count - token.count) <= 1 && editDistance($0, token) <= 1 }) {
            return [near]
        }
        return segment(token, vocabulary: vocabulary)
    }

    /// „sussrahmbutter“ → ["sussrahm", "butter"], wenn beide auf der Packung stehen (Fugen-s erlaubt).
    static func segment(_ token: String, vocabulary: Set<String>) -> [String]? {
        let chars = Array(token)
        let n = chars.count
        guard n >= 6 else { return nil }
        var best: [[String]?] = Array(repeating: nil, count: n + 1)
        best[0] = []
        for end in 1...n {
            for start in 0..<end {
                guard let prefix = best[start] else { continue }
                let piece = String(chars[start..<end])
                if piece.count >= 3 && vocabulary.contains(piece) {
                    best[end] = prefix + [piece]
                    break
                }
                // Fugen-s: „Schweinefleisch“-artige Verbindungen, z. B. „Rahm“ + „s“ + …
                if piece == "s" && !prefix.isEmpty {
                    best[end] = prefix
                    break
                }
            }
        }
        guard let parts = best[n], parts.count >= 2 else { return nil }
        return parts
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        var row = Array(0...b.count)
        for i in 1...max(a.count, 1) where i <= a.count {
            var previous = row[0]
            row[0] = i
            for j in 1...max(b.count, 1) where j <= b.count {
                let current = row[j]
                row[j] = min(row[j] + 1, row[j - 1] + 1, previous + (a[i - 1] == b[j - 1] ? 0 : 1))
                previous = current
            }
        }
        return row[b.count]
    }

    private static func isQuantityToken(_ token: String) -> Bool {
        ProductPhotoRecognizer.parseQuantity(token) != nil && token.first?.isNumber == true
    }

    /// Menge aus dem Foto vs. Katalog: gleich +0,05, verschieden −0,1, unbekannt 0.
    static func quantityAdjustment(_ product: GlobalProductEntry, fields: ProductPhotoFields?) -> Double {
        guard let units = fields?.units, let measure = fields?.measure,
              let catalog = product.measure.flatMap(ProductPhotoRecognizer.parseQuantity) else { return 0 }
        func grams(_ v: Double, _ u: String) -> Double {
            switch u { case "kg", "l": return v * 1000; default: return v }
        }
        return abs(grams(units, measure) - grams(catalog.0, catalog.1)) < 0.5 ? 0.05 : -0.1
    }

    // MARK: - Gelesene Felder verbessern

    /// Marke aus dem Katalog übernehmen, wenn alle ihre Wörter auf der Packung stehen (richtige Schreibweise).
    /// War die gelesene „Marke“ in Wahrheit ein Zusatz über dem Namen („Süßrahm“ über „BUTTER“),
    /// wandert sie in den Namen („Süßrahm Butter“).
    static func refine(_ fields: ProductPhotoFields?, products: [GlobalProductEntry], keywords: [Keyword]) -> ProductPhotoFields? {
        guard var f = fields else { return nil }
        let vocabulary = Set(keywords.map(\.folded))
        let brands = products.compactMap { $0.brand?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } }
            .filter { !$0.isEmpty }
        guard let brand = brands.first(where: { b in
            let w = words(b).map(fold).filter { $0.count >= 3 }
            return !w.isEmpty && w.allSatisfy { vocabulary.contains($0) }
        }) else { return f }
        let brandWords = Set(words(brand).map(fold))
        if let read = f.brand, !words(read).map(fold).contains(where: { brandWords.contains($0) }) {
            let nameWords = Set(words(f.name).map(fold))
            if !words(read).map(fold).allSatisfy({ nameWords.contains($0) }) {
                f.name = ProductPhotoRecognizer.tidy(read) + " " + f.name
            }
        }
        f.brand = brand
        // Markenwörter nicht doppelt im Namen („Rewe Butter“ → „Butter“).
        let cleaned = f.name.split(separator: " ").filter { !brandWords.contains(fold(String($0))) }.joined(separator: " ")
        if !cleaned.isEmpty { f.name = cleaned }
        return f
    }

    // MARK: - Entscheiden

    /// Text- und Mengenbewertung für alle Kandidaten, beste zuerst (noch ohne Bild).
    static func rank(_ products: [GlobalProductEntry], keywords: [Keyword], fields: ProductPhotoFields?) -> [ProductMatchCandidate] {
        let vocabulary = Set(keywords.map(\.folded))
        return products.map { p in
            var text = min(1, max(0, textScore(p, keywords: keywords) + quantityAdjustment(p, fields: fields)))
            if !brandOnPack(p, vocabulary: vocabulary, readBrand: fields?.brand) { text *= 0.6 }
            return ProductMatchCandidate(product: p, textScore: text, visualScore: nil, score: text)
        }
        .sorted { $0.score != $1.score ? $0.score > $1.score : $0.product.scansN > $1.product.scansN }
    }

    /// Steht die Marke des Kandidaten auf der Packung? Ohne gelesene Marke oder ohne Katalogmarke: kein Abzug.
    /// Beispiel: Packung „Hofgut Sonnental Hafer Drink“ → „Hafer Drink Barista · Oatly“ bekommt Abzug.
    static func brandOnPack(_ p: GlobalProductEntry, vocabulary: Set<String>, readBrand: String?) -> Bool {
        guard readBrand?.isEmpty == false, let brand = p.brand, !brand.isEmpty else { return true }
        let brandWords = words(brand).map(fold).filter { $0.count >= 3 && !noise.contains($0) }
        return brandWords.isEmpty || brandWords.contains { vocabulary.contains($0) }
    }

    /// Bildähnlichkeit einrechnen: 75 % Text, 25 % Bild (nur wenn ein Katalogbild geladen werden konnte).
    static func applyVisual(_ candidates: [ProductMatchCandidate], similarity: [String: Double]) -> [ProductMatchCandidate] {
        candidates.map { c in
            var c = c
            if let v = similarity[c.id] {
                c.visualScore = v
                c.score = 0.75 * c.textScore + 0.25 * v
            }
            return c
        }
        .sorted { $0.score > $1.score }
    }

    /// Gleiche Buchstaben in Name + Marke (Reihenfolge, Leerzeichen, Groß/klein egal) und gleiche Menge.
    static func sameProduct(_ a: GlobalProductEntry, _ b: GlobalProductEntry) -> Bool {
        func key(_ p: GlobalProductEntry) -> [Character] {
            fold(p.name + (p.brand ?? "")).filter { $0.isLetter || $0.isNumber }.sorted()
        }
        let qa = a.measure.flatMap(ProductPhotoRecognizer.parseQuantity), qb = b.measure.flatMap(ProductPhotoRecognizer.parseQuantity)
        let sameQuantity = qa == nil || qb == nil || (qa!.0 == qb!.0 && qa!.1 == qb!.1)
        return sameQuantity && key(a) == key(b)
    }

    static func decide(_ candidates: [ProductMatchCandidate]) -> ProductPhotoMatchResult {
        let sorted = candidates.sorted { $0.score > $1.score }
        guard let best = sorted.first else { return .none }
        let second = sorted.dropFirst().first?.score ?? 0
        if best.score >= certainScore && best.score - second >= certainMargin { return .certain(best) }
        // Gleiches Produkt mehrfach im Katalog („Süßrahmbutter · REWE Bio“ / „Bio Süßrahm Butter · Rewe“):
        // Liegen alle knapp dahinter liegenden Treffer auf demselben Produkt, ist es trotzdem sicher (beliebtester).
        if best.score >= certainScore {
            let close = sorted.filter { best.score - $0.score < certainMargin }
            if close.allSatisfy({ sameProduct($0.product, best.product) }) {
                return .certain(close.max { $0.product.scansN < $1.product.scansN } ?? best)
            }
        }
        var likely: [ProductMatchCandidate] = []
        for c in sorted where c.score >= suggestScore && !likely.contains(where: { sameProduct($0.product, c.product) }) {
            likely.append(c)
            if likely.count == 3 { break }
        }
        return likely.isEmpty ? .none : .choose(likely)
    }
}

// MARK: - Bildvergleich

/// Vergleicht das Foto mit den Katalogbildern (Vision-Merkmale, auf dem Gerät).
enum ProductImageSimilarity {
    /// Kandidaten-ID → 0…1 (1 = sehr ähnlich). Bilder, die nicht in 4 s laden, fehlen.
    static func similarity(photo: UIImage, candidates: [ProductMatchCandidate]) async -> [String: Double] {
        let targets: [(String, URL)] = candidates.compactMap { c in
            guard let s = c.product.imageUrl, let url = URL(string: s), url.scheme == "https" else { return nil }
            return (c.id, url)
        }
        guard !targets.isEmpty else { return [:] }
        // 1. Katalogbilder parallel laden (nur Daten).
        let images: [String: Data] = await withTaskGroup(of: (String, Data?).self) { group in
            for (id, url) in targets {
                group.addTask {
                    var request = URLRequest(url: url, timeoutInterval: 4)
                    request.setValue("Famlist/1.0 (iOS; Einkaufsliste)", forHTTPHeaderField: "User-Agent")
                    let data = try? await URLSession.shared.data(for: request).0
                    return (id, data)
                }
            }
            var result: [String: Data] = [:]
            for await (id, data) in group { if let data { result[id] = data } }
            return result
        }
        guard !images.isEmpty else { return [:] }
        // 2. Merkmale und Abstände in einem Hintergrund-Durchlauf.
        return await Task.detached(priority: .userInitiated) { () -> [String: Double] in
            guard let photoPrint = Self.featurePrint(photo) else { return [:] }
            var result: [String: Double] = [:]
            for (id, data) in images {
                guard let image = UIImage(data: data), let print = Self.featurePrint(image) else { continue }
                var distance: Float = 0
                guard (try? photoPrint.computeDistance(&distance, to: print)) != nil else { continue }
                result[id] = Self.similarity(distance: Double(distance))
            }
            return result
        }.value
    }

    /// Abstand → 0…1. Merkmale ab iOS 17 sind normiert (Abstand 0…2); gleiche Packung liegt meist unter 0,5,
    /// fremde Produkte meist über 1,1.
    static func similarity(distance: Double) -> Double {
        min(1, max(0, (1.25 - distance) / 0.8))
    }

    private static func featurePrint(_ image: UIImage) -> VNFeaturePrintObservation? {
        guard let cg = image.cgImage else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: ProductPhotoRecognizer.orientation(image.imageOrientation))
        try? handler.perform([request])
        return request.results?.first
    }
}
