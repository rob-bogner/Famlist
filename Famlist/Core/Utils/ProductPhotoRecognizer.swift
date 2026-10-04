/*
 ProductPhotoRecognizer.swift
 Famlist
 Created on: 30.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - „Per Foto hinzufügen“ (Design: PhotoAddScan): Barcode und Aufschrift aus einem Artikelfoto lesen,
   daraus Name, Marke und Menge ableiten, Beschreibung bei Open Food Facts holen.

 🔰 Notes for Beginners:
 - Alles Lesen passiert auf dem Gerät mit Vision: VNDetectBarcodesRequest (EAN/UPC) und
   VNRecognizeTextRequest (Deutsch/Englisch). Zeilen kommen mit Rahmen (0…1, Ursprung oben links).
 - Ab iOS 27 ordnet das Sprachmodell die Zeilen zu (ProductPhotoModelReader); vorher einfache Regeln:
   größte Schrift = Name (ähnlich große Zeilen direkt darunter gehören dazu), kleinere Zeile darüber = Marke,
   „1 L“, „500 g“ … = Menge.
 - Open Food Facts: nur Lesen per Barcode (world.openfoodfacts.org/api/v2), kostenlos, Quellenangabe
   „Open Food Facts (ODbL)“ im Formular. Ohne Netz → keine Beschreibung.

 📝 Last Change:
 - Initial creation (Wunsch Robert 30.09.2026).
 - Open Food Facts auch für Name/Marke/Menge per Barcode (OpenFoodFactsProduct), 01.10.2026.
 ------------------------------------------------------------------------
 */

import Foundation
import UIKit
import Vision

/// Rohdaten aus dem Foto.
struct ProductPhotoReading: Sendable, Equatable {
    struct Line: Sendable, Equatable {
        let text: String
        /// 0…1, Ursprung oben links (für die Rahmen im Produktkopf).
        let box: CGRect
    }
    var barcode: String?
    var lines: [Line]
}

/// Aus dem Foto abgeleitete Felder.
struct ProductPhotoFields: Sendable, Equatable {
    var name: String
    var brand: String?
    var variant: String?
    var units: Double?
    var measure: String?
    /// Rahmen der erkannten Stellen (Marke, Name, Sorte, Menge) für den Produktkopf.
    var highlights: [PhotoHighlight] = []
}

struct PhotoHighlight: Sendable, Equatable, Identifiable {
    let label: String
    let box: CGRect
    var id: String { label }
}

enum ProductPhotoRecognizer {
    // MARK: - Lesen (Vision)

    static func read(_ image: UIImage) async -> ProductPhotoReading {
        await Task.detached(priority: .userInitiated) { () -> ProductPhotoReading in
            guard let cg = image.cgImage else { return ProductPhotoReading(barcode: nil, lines: []) }
            let handler = VNImageRequestHandler(cgImage: cg, orientation: orientation(image.imageOrientation))
            let barcodes = VNDetectBarcodesRequest()
            barcodes.symbologies = [.ean13, .ean8, .upce, .code128]
            let text = VNRecognizeTextRequest()
            text.recognitionLevel = .accurate
            text.recognitionLanguages = ["de-DE", "en-US"]
            text.usesLanguageCorrection = true
            try? handler.perform([barcodes, text])
            let code = barcodes.results?.compactMap(\.payloadStringValue).first { !$0.isEmpty }
            let lines: [ProductPhotoReading.Line] = (text.results ?? []).compactMap { obs in
                guard let candidate = obs.topCandidates(1).first, candidate.confidence >= 0.3 else { return nil }
                let t = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard t.count >= 1 else { return nil }
                let b = obs.boundingBox        // Vision: Ursprung unten links
                return .init(text: t, box: CGRect(x: b.minX, y: 1 - b.maxY, width: b.width, height: b.height))
            }
            return ProductPhotoReading(barcode: code, lines: lines)
        }.value
    }

    // MARK: - Zuordnen (Regeln, vor iOS 27)

    static func fields(from reading: ProductPhotoReading) -> ProductPhotoFields? {
        var lines = reading.lines
        var quantity: (Double, String)?
        var quantityBox: CGRect?
        if let q = lines.first(where: { parseQuantity($0.text) != nil && isQuantityOnly($0.text) }) {
            quantity = parseQuantity(q.text)
            quantityBox = q.box
            lines.removeAll { $0 == q }
        }
        let words = lines.filter { $0.text.count >= 2 && $0.text.rangeOfCharacter(from: .letters) != nil }
        guard let biggest = words.max(by: { $0.box.height < $1.box.height }) else { return nil }
        // Name: größte Zeile, dazu gleich große Zeilen direkt darunter („Hafer“ / „Drink“).
        var nameLines = [biggest]
        var bottom = biggest.box.maxY
        for line in words.sorted(by: { $0.box.minY < $1.box.minY }) where line != biggest {
            let similar = line.box.height >= biggest.box.height * 0.75
            let below = line.box.minY >= bottom - biggest.box.height * 0.2 && line.box.minY <= bottom + biggest.box.height * 0.8
            if similar && below { nameLines.append(line); bottom = line.box.maxY }
        }
        let nameBox = nameLines.map(\.box).reduce(nameLines[0].box) { $0.union($1) }
        let rest = words.filter { !nameLines.contains($0) }
        // Sorte: kurze Zeile direkt unter dem Namen („BARISTA“).
        let variant = rest.first { $0.box.minY >= nameBox.maxY - 0.01 && $0.box.minY <= nameBox.maxY + nameBox.height * 0.6 && $0.text.count <= 16 }
        // Marke: größte übrige Zeile über dem Namen, sonst größte übrige.
        let others = rest.filter { $0 != variant && $0.box.height >= biggest.box.height * 0.25 }
        let brand = others.filter { $0.box.maxY <= nameBox.minY + 0.02 }.max { $0.box.height < $1.box.height }
            ?? others.max { $0.box.height < $1.box.height }
        // Marke über mehrere Zeilen („HOFGUT“ / „Sonnental“): Zeilen direkt darunter, gleiche Mitte.
        let brandLines: [ProductPhotoReading.Line] = brand.map { b in
            others.filter { $0.box.minY >= b.box.minY - 0.005 && $0.box.minY <= b.box.maxY + b.box.height * 1.4
                && abs($0.box.midX - b.box.midX) < 0.15 }
                .sorted { $0.box.minY < $1.box.minY }
        } ?? []
        var highlights: [PhotoHighlight] = []
        if let first = brandLines.first {
            highlights.append(.init(label: "Marke", box: brandLines.map(\.box).reduce(first.box) { $0.union($1) }))
        }
        highlights.append(.init(label: "Name", box: nameBox))
        if let variant { highlights.append(.init(label: "Sorte", box: variant.box)) }
        if let quantityBox { highlights.append(.init(label: "Menge", box: quantityBox)) }
        let name = nameLines.map { tidy($0.text) }.joined(separator: " ")
        let brandText = brandLines.isEmpty ? nil : brandLines.map { tidy($0.text) }.joined(separator: " ")
        return ProductPhotoFields(name: name, brand: brandText, variant: variant.map { tidy($0.text) },
                                  units: quantity?.0, measure: quantity?.1, highlights: highlights)
    }

    /// „1 L“, „500g“, „0,75 l“, „6 x 1,5 L“ → (Menge, Einheit). Einheit wie in Measure (g, kg, ml, l).
    static func parseQuantity(_ text: String) -> (Double, String)? {
        let pattern = #"(\d+(?:[.,]\d+)?)\s*(kg|g|ml|cl|l|L)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numRange = Range(m.range(at: 1), in: text), let unitRange = Range(m.range(at: 2), in: text),
              let value = Double(text[numRange].replacingOccurrences(of: ",", with: ".")) else { return nil }
        let unit = text[unitRange].lowercased()
        if unit == "cl" { return (value * 10, "ml") }
        return (value, unit)
    }

    private static func isQuantityOnly(_ text: String) -> Bool {
        text.count <= 14 && text.rangeOfCharacter(from: .decimalDigits) != nil
    }

    /// „HAFER“ → „Hafer“; gemischte Schreibweise bleibt.
    static func tidy(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t == t.uppercased(), t.count > 3 else { return t }
        return t.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    static func orientation(_ o: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch o {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

/// Produkt per Barcode direkt bei Open Food Facts (wenn es nicht im eigenen oder globalen Katalog steht).
struct OpenFoodFactsProduct: Sendable, Equatable {
    var name: String?
    var brand: String?
    var quantity: String?
    var category: String?
    var imageUrl: String?
    /// Kurzbeschreibung + Zutaten, höchstens 400 Zeichen.
    var description: String?

    private struct Response: Decodable {
        struct Product: Decodable {
            let product_name_de: String?
            let product_name: String?
            let brands: String?
            let quantity: String?
            let image_front_url: String?
            let generic_name_de: String?
            let generic_name: String?
            let ingredients_text_de: String?
            let ingredients_text: String?
        }
        let status: Int?
        let product: Product?
    }

    static func fetch(barcode: String) async -> OpenFoodFactsProduct? {
        let code = barcode.filter(\.isNumber)
        let fields = "product_name_de,product_name,brands,quantity,image_front_url,generic_name_de,generic_name,ingredients_text_de,ingredients_text"
        guard !code.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=\(fields)") else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("Famlist/1.0 (iOS; Einkaufsliste)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: data),
              decoded.status == 1, let p = decoded.product else { return nil }
        func first(_ values: [String?]) -> String? {
            values.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        }
        let generic = first([p.generic_name_de, p.generic_name])
        let ingredients = first([p.ingredients_text_de, p.ingredients_text])
        var parts: [String] = []
        if let generic { parts.append(generic.hasSuffix(".") ? generic : generic + ".") }
        if let ingredients {
            let clean = ingredients.replacingOccurrences(of: "_", with: "")
            parts.append("Zutaten: " + (clean.hasSuffix(".") ? clean : clean + "."))
        }
        let text = parts.joined(separator: " ")
        let description = text.isEmpty ? nil : (text.count > 400 ? String(text.prefix(397)) + "…" : text)
        let brand = first([p.brands])?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
        return OpenFoodFactsProduct(name: first([p.product_name_de, p.product_name]), brand: brand,
                                    quantity: first([p.quantity]), category: nil,
                                    imageUrl: first([p.image_front_url]), description: description)
    }
}

/// Beschreibung (Kurzbeschreibung + Zutaten) aus Open Food Facts.
enum OpenFoodFactsDescription {
    static func fetch(barcode: String) async -> String? {
        await OpenFoodFactsProduct.fetch(barcode: barcode)?.description
    }
}
