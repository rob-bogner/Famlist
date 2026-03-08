/*
 ClipboardImportParser.swift
 Created: 19.10.2025 | Updated: 19.10.2025
 
 Purpose: Parses shopping list items from clipboard text with category sections
 
 CHANGELOG:
 - 19.10.2025: Initial version - supports category headers and item parsing
*/

import Foundation

/// Parses clipboard text containing shopping items organized by categories
struct ClipboardImportParser {
    
    /// Parsed item with extracted metadata
    struct ParsedItem {
        let name: String
        let units: Int
        let measure: String
        let category: String?
        let brand: String?
    }
    
    /// Result of parsing clipboard content
    struct ParseResult {
        let items: [ParsedItem]
        let storeName: String?
        let skippedLines: [String]
    }
    
    // MARK: - Public API
    
    /// Parses clipboard text into structured items
    /// - Parameter text: Raw clipboard text with categories in brackets
    /// - Returns: ParseResult with items, optional store name, and skipped lines
    static func parse(_ text: String) -> ParseResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var items: [ParsedItem] = []
        var currentCategory: String?
        var storeName: String?
        var skippedLines: [String] = []
        
        for (index, line) in lines.enumerated() {
            // First non-category line is store name
            if index == 0 && !line.hasPrefix("[") {
                storeName = line
                continue
            }
            
            // Category header like [Obst & Gemüse]
            if line.hasPrefix("[") && line.hasSuffix("]") {
                currentCategory = String(line.dropFirst().dropLast())
                continue
            }
            
            // Parse item line
            if let parsed = parseItemLine(line, category: currentCategory) {
                items.append(parsed)
            } else {
                skippedLines.append(line)
            }
        }
        
        return ParseResult(items: items, storeName: storeName, skippedLines: skippedLines)
    }
    
    // MARK: - Private Helpers
    
    /// Parses a single item line extracting quantity, measure, brand, and name
    private static func parseItemLine(_ line: String, category: String?) -> ParsedItem? {
        guard !line.isEmpty else { return nil }

        var remainingText = line
        var units = 1
        var measure = ""
        var brand: String?

        // Extract quantity and measure (e.g., "500 g", "1x", "2 Liter")
        if let quantityMatch = extractQuantityAndMeasure(from: remainingText) {
            units = quantityMatch.units
            measure = quantityMatch.measure
            remainingText = quantityMatch.remainingText
        } else if let suffixMatch = extractSuffixQuantity(from: remainingText) {
            // Handles suffix quantities like "Milch 1x" or "Frischkäse 2x"
            units = suffixMatch.units
            measure = suffixMatch.measure
            remainingText = suffixMatch.remainingText
        }

        // Extract brand (assuming remaining text after quantity is "Brand ProductName")
        let components = remainingText.components(separatedBy: " ")

        // If first word is capitalized and followed by more words, treat as brand
        if components.count > 1 && components[0].first?.isUppercase == true {
            let firstWord = components[0]
            // Check if it looks like a brand (not a common word like "Die", "Der", etc.)
            if firstWord.count > 2 && !["Die", "Der", "Das", "Ein", "Eine"].contains(firstWord) {
                brand = firstWord
                remainingText = components.dropFirst().joined(separator: " ")
            }
        }

        // Clean up name
        let name = remainingText.trimmingCharacters(in: .whitespaces)

        // Skip items whose name is purely a parenthetical annotation (e.g. "(150 g)")
        guard !name.isEmpty, !(name.hasPrefix("(") && name.hasSuffix(")")) else { return nil }

        return ParsedItem(
            name: name,
            units: units,
            measure: measure,
            category: category,
            brand: brand
        )
    }
    
    /// Extracts a trailing quantity suffix like "Milch 1x" → name="Milch", units=1, measure="x"
    private static func extractSuffixQuantity(from text: String) -> (units: Int, measure: String, remainingText: String)? {
        let pattern = #"^(.+?)\s+(\d+)(x)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let nameRange = Range(match.range(at: 1), in: text),
              let unitsRange = Range(match.range(at: 2), in: text),
              let measureRange = Range(match.range(at: 3), in: text) else {
            return nil
        }
        return (
            units: Int(text[unitsRange]) ?? 1,
            measure: String(text[measureRange]),
            remainingText: String(text[nameRange])
        )
    }

    /// Extracts quantity and measure from text like "500 g Hähnchenbrust" or "1x Butter"
    private static func extractQuantityAndMeasure(from text: String) -> (units: Int, measure: String, remainingText: String)? {
        let pattern = #"^(\d+)\s*(g|kg|ml|l|Liter|x|Stück|Becher|Packung|Dose|Flasche)?\s*(.*)$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        let unitsRange = Range(match.range(at: 1), in: text)!
        let units = Int(text[unitsRange]) ?? 1
        
        var measure = ""
        if match.range(at: 2).location != NSNotFound,
           let measureRange = Range(match.range(at: 2), in: text) {
            measure = String(text[measureRange])
        }
        
        var remainingText = ""
        if match.range(at: 3).location != NSNotFound,
           let remainingRange = Range(match.range(at: 3), in: text) {
            remainingText = String(text[remainingRange]).trimmingCharacters(in: .whitespaces)
        }
        
        return (units, measure, remainingText)
    }
}
