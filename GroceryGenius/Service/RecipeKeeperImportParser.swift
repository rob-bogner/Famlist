// filepath: GroceryGenius/Service/RecipeKeeperImportParser.swift
// MARK: - RecipeKeeperImportParser.swift

import Foundation

public struct ImportedItem: Equatable {
    public let title: String
    public let note: String?
    public let qty: Double?
    public let unit: String?
    public let category: String?
}

public struct RecipeKeeperImport: Equatable {
    public let items: [ImportedItem]
}

public enum RecipeKeeperImportParser {
    // Public API
    public static func parse(_ text: String) -> RecipeKeeperImport {
        // 1) Normalize input
        var normalized = text
        // Remove UTF-8 BOM if present
        if normalized.hasPrefix("\u{FEFF}") { normalized.removeFirst() }
        // Normalize newlines to \n
        normalized = normalized.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        // Split lines
        var lines = normalized.components(separatedBy: "\n")
        // Drop leading empty lines
        while let first = lines.first, first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.removeFirst()
        }
        // Drop the first non-empty line (foreign list title)
        if !lines.isEmpty { lines.removeFirst() }

        // Parsing state
        var currentCategory: String? = nil
        var items: [ImportedItem] = []

        let categoryRegex = try! NSRegularExpression(pattern: "^\\s*\\[(.+?)\\]\\s*$")
        let qtyUnitRegex = try! NSRegularExpression(pattern: "^\\s*(\\d+(?:[.,]\\d+)?)\\s*([A-Za-zÄÖÜäöü]+)\\s+(.+)$")
        let qtyOnlyRegex = try! NSRegularExpression(pattern: "^\\s*(\\d+(?:[.,]\\d+)?)\\s+(.+)$")

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            // Category header?
            if let m = categoryRegex.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)),
               let catRange = Range(m.range(at: 1), in: line) {
                let cat = String(line[catRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                currentCategory = cat
                continue
            }

            // Item line
            let preprocessed = normalizeUnicodeFractions(in: line)

            // Pass 1: qty + unit + remainder
            if let m = qtyUnitRegex.firstMatch(in: preprocessed, range: NSRange(location: 0, length: preprocessed.utf16.count)),
               let qtyR = Range(m.range(at: 1), in: preprocessed),
               let unitR = Range(m.range(at: 2), in: preprocessed),
               let restR = Range(m.range(at: 3), in: preprocessed) {

                let qtyString = String(preprocessed[qtyR]).replacingOccurrences(of: ",", with: ".")
                let qty = Double(qtyString)
                let unit = String(preprocessed[unitR]).trimmingCharacters(in: .whitespaces)
                let remainder = String(preprocessed[restR]).trimmingCharacters(in: .whitespaces)
                let (title, note) = splitTitleAndNote(from: remainder)
                let item = ImportedItem(title: title, note: note, qty: qty, unit: mapUnit(unit), category: currentCategory ?? "Andere")
                items.append(item)
                continue
            }

            // Pass 2: qty only + remainder
            if let m = qtyOnlyRegex.firstMatch(in: preprocessed, range: NSRange(location: 0, length: preprocessed.utf16.count)),
               let qtyR = Range(m.range(at: 1), in: preprocessed),
               let restR = Range(m.range(at: 2), in: preprocessed) {
                let qtyString = String(preprocessed[qtyR]).replacingOccurrences(of: ",", with: ".")
                let qty = Double(qtyString)
                let remainder = String(preprocessed[restR]).trimmingCharacters(in: .whitespaces)
                let (title, note) = splitTitleAndNote(from: remainder)
                let item = ImportedItem(title: title, note: note, qty: qty, unit: nil, category: currentCategory ?? "Andere")
                items.append(item)
                continue
            }

            // Fallback: whole line as title
            let item = ImportedItem(title: preprocessed, note: nil, qty: nil, unit: nil, category: currentCategory ?? "Andere")
            items.append(item)
        }

        return RecipeKeeperImport(items: items)
    }

    // MARK: - Helpers
    private static func normalizeUnicodeFractions(in s: String) -> String {
        var out = s
        let mapping: [String: String] = [
            "½": "0.5",
            "⅓": "0.3333",
            "¼": "0.25"
        ]
        for (k, v) in mapping { out = out.replacingOccurrences(of: k, with: v) }
        return out
    }

    private static func splitTitleAndNote(from remainder: String) -> (String, String?) {
        // If a comma exists, take first part as title, rest as note
        if let idx = remainder.firstIndex(of: ",") {
            let title = remainder[..<idx].trimmingCharacters(in: .whitespaces)
            let noteRaw = remainder[remainder.index(after: idx)...].trimmingCharacters(in: .whitespaces)
            let note = noteRaw.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
            return (String(title), note.isEmpty ? nil : note)
        }
        return (remainder, nil)
    }

    private static func mapUnit(_ raw: String) -> String {
        // Lightweight unit mapping. Keep original if not known.
        let t = raw.trimmingCharacters(in: .whitespaces)
        let candidates: [String: String] = [
            "g": "g",
            "kg": "kg",
            "ml": "ml",
            "l": "l",
            "L": "l",
            "EL": "EL",
            "Tl": "TL", "TL": "TL", "tl": "TL",
            "Bund": "Bund",
            "Pack": "Pack",
            "Stück": "Stück", "Stk": "Stück", "stk": "Stück",
            "Dose": "Dose",
            "Tube": "Tube",
            "Becher": "Becher"
        ]
        return candidates[t] ?? t
    }
}
