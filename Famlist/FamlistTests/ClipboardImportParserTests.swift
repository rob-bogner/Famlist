/*
 ClipboardImportParserTests.swift
 Created: 19.10.2025 | Updated: 19.10.2025
 
 Purpose: Unit tests for ClipboardImportParser with real-world examples
 
 CHANGELOG:
 - 19.10.2025: Initial test cases
*/

import XCTest
@testable import Famlist

final class ClipboardImportParserTests: XCTestCase {
    
    func testParseEdekaExample() {
        let input = """
        Edeka 

        [Alnatura]
        Eier

        [Obst & Gemüse]
        Cocktailtomaten
        Bananen

        [Fleisch & Wurst]
        500 g Hähnchenbrust

        [Milchprodukte]
        Joghurt Griechischer Art
        1 Becher Joghurt (150 g)
        Frischkäse 1x
        Butter

        [Tiefkühlprodukte]
        Aufbackbrezen

        [Andere]
        Käse
        Apfelsaft
        Milch 1x
        Fruchtjoghurt
        """
        
        let result = ClipboardImportParser.parse(input)
        
        // Store name
        XCTAssertEqual(result.storeName, "Edeka")
        
        // Should parse all items
        XCTAssertEqual(result.items.count, 12)
        
        // Check specific items
        let eier = result.items.first { $0.name == "Eier" }
        XCTAssertNotNil(eier)
        XCTAssertEqual(eier?.category, "Alnatura")
        XCTAssertEqual(eier?.units, 1)
        
        let chicken = result.items.first { $0.name.contains("Hähnchenbrust") }
        XCTAssertNotNil(chicken)
        XCTAssertEqual(chicken?.category, "Fleisch & Wurst")
        XCTAssertEqual(chicken?.units, 500)
        XCTAssertEqual(chicken?.measure, "g")
        
        let milk = result.items.first { $0.name == "Milch" }
        XCTAssertNotNil(milk)
        XCTAssertEqual(milk?.units, 1)
        XCTAssertEqual(milk?.measure, "x")
    }
}
