/*
 ReceiptItemMatcher.swift
 Famlist
 Created on: 24.09.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Ordnet abgekürzte Bon-Texte („KOKOSM. 400ML“) den Artikeln des Nutzers zu (unscharfer Namensabgleich).

 🔰 Notes for Beginners:
 - Beide Seiten werden vereinfacht: klein, ohne Umlaute/Akzente (auch „ae/oe/ue“), nur Buchstaben und Ziffern.
 - Punktzahl 0…1 = Maximum aus
   • Wortpräfix: Anteil der Bon-Wörter (ab 3 Zeichen, ohne Mengenangaben), die Anfang eines Artikelworts sind
     oder umgekehrt („kokosm“ → „kokosmilch“),
   • Trigramm-Ähnlichkeit (Dice) der zusammengesetzten Texte.
 - Status wie im Design: ≥ 0,75 „Zugeordnet“, ≥ 0,45 „Zuordnung prüfen“, sonst „Neuer Artikel?“.

 📝 Last Change:
 - Initial creation (Redesign „Hybrid“, Phase 7).
 ------------------------------------------------------------------------
 */

import Foundation

enum ReceiptItemMatcher {
    enum Status: Equatable {
        case matched
        case check
        case new
    }

    struct Match: Equatable {
        let candidate: String?
        let score: Double
        let status: Status
    }

    static let matchedThreshold = 0.75
    static let checkThreshold = 0.45

    static func match(_ raw: String, candidates: [String]) -> Match {
        var best: (String, Double)?
        for candidate in candidates {
            let s = score(raw, candidate)
            if s > (best?.1 ?? 0) { best = (candidate, s) }
        }
        guard let (name, value) = best, value >= checkThreshold else {
            return Match(candidate: best?.0, score: best?.1 ?? 0, status: .new)
        }
        return Match(candidate: name, score: value, status: value >= matchedThreshold ? .matched : .check)
    }

    /// Beste Vorschläge für die Korrektur (absteigend).
    static func suggestions(_ raw: String, candidates: [String], limit: Int = 5) -> [String] {
        candidates.map { ($0, score(raw, $0)) }
            .filter { $0.1 > 0.2 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit).map(\.0)
    }

    static func score(_ raw: String, _ candidate: String) -> Double {
        let r = tokens(raw), c = tokens(candidate)
        guard !r.isEmpty, !c.isEmpty else { return 0 }
        let hits = r.filter { rt in c.contains { ct in ct.hasPrefix(rt) || rt.hasPrefix(ct) } }.count
        let prefixScore = Double(hits) / Double(r.count)
        return max(prefixScore, dice(r.joined(), c.joined()))
    }

    /// Wörter ab 3 Zeichen, ohne reine Zahlen/Mengen („400ml“, „1l“, „250g“).
    static func tokens(_ text: String) -> [String] {
        // Bons schreiben Umlaute oft als AE/OE/UE → wie „ä/ö/ü“ behandeln (beide Seiten gleich).
        let folded = text.lowercased()
            .replacingOccurrences(of: "ae", with: "a").replacingOccurrences(of: "oe", with: "o")
            .replacingOccurrences(of: "ue", with: "u").replacingOccurrences(of: "ß", with: "ss")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
        return folded.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
            .filter { $0.range(of: #"^\d+([a-z]{1,2})?$"#, options: .regularExpression) == nil }
    }

    private static func dice(_ a: String, _ b: String) -> Double {
        func grams(_ s: String) -> [String] {
            let chars = Array(s)
            guard chars.count >= 3 else { return [s] }
            return (0...(chars.count - 3)).map { String(chars[$0..<$0 + 3]) }
        }
        let ga = grams(a), gb = grams(b)
        var pool = gb
        var common = 0
        for g in ga { if let i = pool.firstIndex(of: g) { common += 1; pool.remove(at: i) } }
        return Double(2 * common) / Double(ga.count + gb.count)
    }
}
