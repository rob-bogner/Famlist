/*
 ClipboardImportParser+Units.swift
 Famlist
 Created on: 25.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Einheiten des Clipboard-Imports: unterstützte und verworfene Einheiten, Einheiten-Konsum und Umrechnung in ganze Einheiten.

 📝 Last Change:
 - Aus ClipboardImportParser.swift ausgelagert (Audit 25.09.2026).
 ------------------------------------------------------------------------
 */

import Foundation

extension ClipboardImportParser {
    // MARK: - Einheiten-Definitionen

    /// Mappe: lowercase Alias → kanonischer Measure-rawValue (nur App-unterstützte Einheiten).
    static let supportedUnitsMap: [String: String] = [
        // Gewicht
        "g": "g", "gramm": "g", "gram": "g",
        "kg": "kg", "kilogramm": "kg", "kilogram": "kg", "kilo": "kg",
        // Volumen
        "ml": "ml", "milliliter": "ml", "millilitre": "ml",
        "l": "l", "liter": "l",
        // Länge (in Measure-Enum vorhanden)
        "m": "m", "meter": "m",
        // Verpackungstypen
        "stück": "piece", "stücke": "piece", "stk": "piece", "stk.": "piece",
        "packung": "pack", "packungen": "pack", "pck": "pack", "pck.": "pack",
        "dose": "can",     "dosen": "can",
        "flasche": "bottle", "flaschen": "bottle",
        "glas": "jar",     "gläser": "jar",
        "bund": "bunch",   "bünde": "bunch",
        "karton": "carton","kartons": "carton",
        "box": "box",      "boxen": "box",
        "netz": "net",     "netze": "net",
        "paar": "pair",    "paare": "pair",
        "sack": "sack",    "säcke": "sack",
        "tüte": "bag",     "tüten": "bag",
        "riegel": "bar",
        "tube": "tube",    "tuben": "tube",
        "kiste": "crate",  "kisten": "crate",
        "beutel": "smallBag",
    ]

    /// Bekannte, aber NICHT von der App unterstützte Einheiten-Tokens (lowercase).
    /// Diese werden beim Parsing still verworfen – sie landen weder im measure noch im Namen.
    private static let knownUnsupportedTokens: Set<String> = [
        "el", "tl",
        "schuss", "prise",
        "scheibe", "scheiben", "scheibe/n",
        "becher",
        "zehe", "zehen",
        "litres", "litre",
        "cm", "zentimeter",
        "cl", "dl",
        "pak", "x",
    ]

    /// Dezimalmengen dieser Einheiten werden in die kleinere Einheit umgerechnet.
    /// Ziel-Tokens sind die rawValues der `Measure`-Enum (dieselben, die `MeasureCanonicalizer` liefert).
    private static let smallerUnits: [String: (measure: String, factor: Double)] = [
        Measure.kg.rawValue: (Measure.g.rawValue, 1000),
        Measure.l.rawValue:  (Measure.ml.rawValue, 1000),
        Measure.m.rawValue:  (Measure.cm.rawValue, 100),
    ]

    /// Kombinierte, nach Länge absteigend sortierte Liste aller bekannten Einheiten-Tokens.
    /// Längere Tokens zuerst verhindert, dass "m" vor "ml" oder "litres" vor "l" greift.
    private static let sortedAllKnownUnits: [(token: String, canonical: String?)] = {
        var result: [(String, String?)] = []
        for (key, value) in supportedUnitsMap    { result.append((key, value)) }
        for key in knownUnsupportedTokens        { result.append((key, nil)) }
        return result.sorted { $0.0.count > $1.0.count }
    }()

    // MARK: - Stage 3c: Einheiten-Konsum

    /// Konsumiert führende bekannte Einheiten-Tokens gierig.
    ///
    /// - Unterstützte Einheit gefunden → als `measure` speichern, danach stoppen.
    /// - Nicht unterstützte Einheit gefunden → still verwerfen, weiter suchen.
    /// - Unbekanntes Wort → stoppen; dieses Wort ist der Beginn des Artikelnamens.
    ///
    /// Rückgabe `hadUnsupportedToken`: true wenn mindestens ein nicht unterstütztes Token
    /// konsumiert wurde und keine unterstützte Einheit gefunden wurde. Wird in `parseItemLine`
    /// genutzt, um die Mengenangabe bei reinen Küchen-Einheiten (EL, TL, Schuss …) zu verwerfen.
    ///
    /// Beispiele:
    /// - `"g Hähnchen"` → measure="g", remaining="Hähnchen", hadUnsupported=false
    /// - `"cm Scheibe Ingwer"` → measure="", remaining="Ingwer", hadUnsupported=true
    /// - `"EL Sojasauce"` → measure="", remaining="Sojasauce", hadUnsupported=true
    /// - `"Eier"` → measure="", remaining="Eier", hadUnsupported=false
    static func consumeUnitTokens(
        from text: String
    ) -> (measure: String, remaining: String, hadUnsupportedToken: Bool) {
        var current = text.trimmingCharacters(in: .whitespaces)
        var hadUnsupported = false

        while !current.isEmpty {
            let lower = current.lowercased()
            var matchedToken: String?
            var matchedCanonical: String?

            for (token, canonical) in sortedAllKnownUnits {
                guard lower.hasPrefix(token) else { continue }
                let afterIdx   = current.index(current.startIndex, offsetBy: token.count)
                let atBoundary = afterIdx >= current.endIndex || current[afterIdx].isWhitespace
                guard atBoundary else { continue }
                matchedToken     = token
                matchedCanonical = canonical
                break
            }

            guard let token = matchedToken else { break }

            let afterIdx = current.index(current.startIndex, offsetBy: token.count)
            current = String(current[afterIdx...]).trimmingCharacters(in: .whitespaces)

            if let canonical = matchedCanonical {
                return (canonical, current, false)   // Unterstützte Einheit → speichern & stop
            }
            // Nicht unterstütztes Token → verwerfen & weitersuchen
            hadUnsupported = true
        }
        return ("", current, hadUnsupported)
    }

    // MARK: - Hilfsfunktionen

    /// Wandelt eine explizite Menge in ganze Einheiten um (Minimum 1).
    /// - Ohne Einheit → "piece".
    /// - Dezimalmenge bei kg/l/m → kleinere Einheit: 1,5 kg → 1500 g, 0,5 l → 500 ml, 1,5 m → 150 cm.
    /// - Sonst aufrunden auf ganze Stück: 1,5 Brot → 2, 0,5 → 1, 3,0 → 3.
    static func resolveUnits(_ quantity: Double, measure: String) -> (units: Int, measure: String) {
        let measure = measure.isEmpty ? "piece" : measure
        let isWhole = abs(quantity - quantity.rounded()) < 0.0001
        if !isWhole, let smaller = smallerUnits[measure] {
            return (max(1, Int((quantity * smaller.factor).rounded())), smaller.measure)
        }
        // Kleine Toleranz, damit Rundungsfehler (2.0000001) nicht auf 3 aufrunden.
        return (max(1, Int((quantity - 0.0001).rounded(.up))), measure)
    }
}
