/*
 ClipboardImportParserTests.swift
 Created: 19.10.2025 | Updated: 16.03.2026

 Purpose: Unit-Tests für ClipboardImportParser

 CHANGELOG:
 - 19.10.2025: Initial
 - 14.03.2026: FAM-60 – Ranges, Brüche, Komma-/Klammer-Notizen
 - 14.03.2026: FAM-60 cont. – Pipeline-Refactor: führende Klammern, Dezimalzahlen,
               kanonisches Measure-Mapping, nicht unterstützte Einheiten verworfen
 - 16.03.2026: FAM-71 – Tests für ParsedItem.stableId(forList:)
*/

import XCTest
@testable import Famlist

final class ClipboardImportParserTests: XCTestCase {

    // MARK: - Edeka Regression

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
        XCTAssertEqual(result.storeName, "Edeka")
        XCTAssertEqual(result.items.count, 13)

        let eier = result.items.first { $0.name == "Eier" }
        XCTAssertNotNil(eier)
        XCTAssertEqual(eier?.category, "Alnatura")
        XCTAssertEqual(eier?.units, 1)

        let chicken = result.items.first { $0.name.contains("Hähnchenbrust") }
        XCTAssertNotNil(chicken)
        XCTAssertEqual(chicken?.units, 500)
        XCTAssertEqual(chicken?.measure, "g")

        // "Milch 1x" → Suffix-Parsing → units=1, measure="piece"
        let milk = result.items.first { $0.name == "Milch" }
        XCTAssertNotNil(milk)
        XCTAssertEqual(milk?.units, 1)
        XCTAssertEqual(milk?.measure, "piece")

        // "1 Becher Joghurt (150 g)" → Becher nicht unterstützt → Menge verworfen
        //  → name="Joghurt", note="(150 g)", units=1, measure=""
        let joghurt = result.items.first { $0.name == "Joghurt" && $0.measure == "" }
        XCTAssertNotNil(joghurt)
        XCTAssertEqual(joghurt?.units, 1)
    }

    // MARK: - Führende Klammer-Menge  (2)

    func test_leadingParen_simple() {
        let result = parse("[W]\n(2) Salz und Pfeffer")
        XCTAssertEqual(result.items.count, 1)
        let item = result.items[0]
        XCTAssertEqual(item.units, 2)
        XCTAssertEqual(item.measure, "piece")
        XCTAssertEqual(item.name, "Salz und Pfeffer")
    }

    func test_leadingParen_threeEggs() {
        let result = parse("[E]\n(3) Eier")
        XCTAssertEqual(result.items[0].units, 3)
        XCTAssertEqual(result.items[0].measure, "piece")
        XCTAssertEqual(result.items[0].name, "Eier")
    }

    func test_leadingParen_rangeRemainsInName() {
        // Führende Klammer hat Vorrang – "2-3 Frühlingszwiebeln" bleibt als Name
        let result = parse("[G]\n(2) 2-3 Frühlingszwiebeln")
        XCTAssertEqual(result.items.count, 1)
        let item = result.items[0]
        XCTAssertEqual(item.units, 2)
        XCTAssertEqual(item.measure, "piece")
        XCTAssertEqual(item.name, "2-3 Frühlingszwiebeln")
    }

    // MARK: - Dezimalzahlen

    func test_decimal_comma_litres() {
        // "litres" nicht unterstützt → Menge verworfen, units=1, measure=""
        let result = parse("[F]\n1,08 litres Gemüsebrühe")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Gemüsebrühe")
    }

    func test_decimal_subOne_cm_scheibe() {
        // "cm" nicht unterstützt → Menge verworfen, units=1, measure=""
        // "Scheibe" wird danach auch verworfen (ebenfalls nicht unterstützt)
        let result = parse("[G]\n0,3 cm Scheibe Ingwer")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Ingwer")
    }

    // MARK: - Brüche

    func test_fraction_halfQuantity() {
        // 1/2 TL → TL nicht unterstützt → Menge verworfen, units=1, measure=""
        let result = parse("[G]\n1/2 TL Ingwer, geriebener")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Ingwer")
        XCTAssertEqual(item.productDescription, "geriebener")
    }

    func test_fraction_halfBecherCremefine() {
        // Becher nicht unterstützt → Menge verworfen, units=1, measure=""
        let result = parse("[M]\n1/2 Becher Cremefine oder Schmand")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Cremefine oder Schmand")
    }

    // MARK: - Bereiche (obere Grenze)

    func test_range_upperBound() {
        // "2-3" → obere Grenze = 3
        let result = parse("[G]\n2-3 Frühlingszwiebeln")
        let item = result.items[0]
        XCTAssertEqual(item.units, 3)
        XCTAssertEqual(item.measure, "piece")
        XCTAssertEqual(item.name, "Frühlingszwiebeln")
    }

    // MARK: - Nicht unterstützte Einheiten werden verworfen

    func test_EL_discarded() {
        // EL nicht unterstützt → Menge verworfen, units=1, measure=""
        let result = parse("[S]\n3 EL Sojasauce")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Sojasauce")
    }

    func test_TL_discarded() {
        // TL nicht unterstützt → Menge verworfen, units=1, measure=""
        let result = parse("[G]\n1 TL Salz")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Salz")
    }

    func test_TL_Gemuesebruehe() {
        // TL nicht unterstützt → Menge verworfen, units=1, measure=""
        let result = parse("[F]\n1 TL Gemüsebrühe")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Gemüsebrühe")
    }

    func test_schuss_discarded() {
        // Schuss nicht unterstützt → Menge verworfen, units=1, measure=""
        let result = parse("[A]\n2 Schuss Milch oder Sahne")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Milch oder Sahne")
    }

    func test_scheibe_slash_n_discarded() {
        // Scheibe/n nicht unterstützt → Menge verworfen, units=1, measure=""
        let result = parse("[B]\n16 Scheibe/n Toastbrot")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Toastbrot")
    }

    // MARK: - Unterstützte Einheiten werden korrekt übernommen

    func test_g_supported() {
        let result = parse("[F]\n500g Hähnchenbrustfilet, in Streifen schneiden")
        let item = result.items[0]
        XCTAssertEqual(item.units, 500)
        XCTAssertEqual(item.measure, "g")
        XCTAssertEqual(item.name, "Hähnchenbrustfilet")
        XCTAssertEqual(item.productDescription, "in Streifen schneiden")
    }

    func test_g_withParenNote() {
        let result = parse("[T]\n280g Reis (Jasmin Reis 2:2,6) als Beilage kochen")
        let item = result.items[0]
        XCTAssertEqual(item.units, 280)
        XCTAssertEqual(item.measure, "g")
        XCTAssertEqual(item.name, "Reis")
        XCTAssertEqual(item.productDescription, "(Jasmin Reis 2:2,6) als Beilage kochen")
    }

    func test_dose_mapsTo_can() {
        let result = parse("[K]\n3 Dosen Tomaten")
        XCTAssertEqual(result.items[0].measure, "can")
        XCTAssertEqual(result.items[0].units, 3)
        XCTAssertEqual(result.items[0].name, "Tomaten")
    }

    func test_flasche_mapsTo_bottle() {
        let result = parse("[G]\n1 Flasche Wasser")
        XCTAssertEqual(result.items[0].measure, "bottle")
        XCTAssertEqual(result.items[0].name, "Wasser")
    }

    func test_stueck_mapsTo_piece() {
        let result = parse("[G]\n2 Stück Paprika")
        XCTAssertEqual(result.items[0].measure, "piece")
        XCTAssertEqual(result.items[0].units, 2)
        XCTAssertEqual(result.items[0].name, "Paprika")
    }

    // MARK: - Komma- und Klammer-Notizen

    func test_commaNoteBasic() {
        let result = parse("[W]\nSalz und Pfeffer, nach Geschmack")
        let item = result.items[0]
        XCTAssertEqual(item.name, "Salz und Pfeffer")
        XCTAssertEqual(item.productDescription, "nach Geschmack")
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
    }

    func test_spaceBeforeComma() {
        let result = parse("[G]\n250 g Blattspinat , frischer")
        let item = result.items[0]
        XCTAssertEqual(item.name, "Blattspinat")
        XCTAssertEqual(item.measure, "g")
        XCTAssertEqual(item.productDescription, "frischer")
    }

    func test_commaInsideParens_notSplit() {
        // Komma innerhalb von () darf NICHT als Notiz-Trenner wirken
        let result = parse("[T]\nReis (Jasmin Reis 1:1,3)")
        let item = result.items[0]
        XCTAssertEqual(item.name, "Reis")
        XCTAssertEqual(item.productDescription, "(Jasmin Reis 1:1,3)")
    }

    // MARK: - Suffix 1x

    func test_suffix1x_noMeasure() {
        let result = parse("[M]\nFrischkäse 1x")
        let item = result.items[0]
        XCTAssertEqual(item.name, "Frischkäse")
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "piece")
    }

    // MARK: - Sonstige Basis-Tests

    func test_noQuantity_plainItem() {
        let result = parse("[A]\nBananen")
        XCTAssertEqual(result.items[0].name, "Bananen")
        XCTAssertEqual(result.items[0].units, 1)
        XCTAssertEqual(result.items[0].measure, "")
    }

    func test_noQuantityOnFirstLine_isStoreName() {
        let result = ClipboardImportParser.parse("Edeka\n\n[Obst]\nÄpfel")
        XCTAssertEqual(result.storeName, "Edeka")
        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items[0].name, "Äpfel")
    }

    func test_emptyInput() {
        let result = ClipboardImportParser.parse("")
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertNil(result.storeName)
    }

    func test_categoryAssignment() {
        let input = "Liste\n\n[Gemüse]\nZucchini\nKarotten\n\n[Milch]\nButter"
        let result = ClipboardImportParser.parse(input)
        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.items.filter { $0.category == "Gemüse" }.count, 2)
        XCTAssertEqual(result.items.filter { $0.category == "Milch" }.count, 1)
    }

    // MARK: - piece-Fallback vs. Küchen-Einheiten

    /// Explizite Stückzahl ohne Einheit → piece-Fallback greift
    func test_piece_fallback_bareCount() {
        let result = parse("[M]\n3 Eier")
        let item = result.items[0]
        XCTAssertEqual(item.units, 3)
        XCTAssertEqual(item.measure, "piece")
        XCTAssertEqual(item.name, "Eier")
    }

    /// Führende Klammer-Menge ohne Einheit → piece-Fallback greift
    func test_piece_fallback_leadingParen() {
        let result = parse("[W]\n(2) Salz und Pfeffer")
        let item = result.items[0]
        XCTAssertEqual(item.units, 2)
        XCTAssertEqual(item.measure, "piece")
        XCTAssertEqual(item.name, "Salz und Pfeffer")
    }

    /// TL → nicht unterstützt → Menge verworfen (kein piece)
    func test_no_piece_when_unsupported_unit_TL() {
        let result = parse("[G]\n2 TL Sambal Oelek")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Sambal Oelek")
    }

    /// EL → nicht unterstützt → Menge verworfen (kein piece)
    func test_no_piece_when_unsupported_unit_EL() {
        let result = parse("[G]\n1 EL Sojasauce")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Sojasauce")
    }

    func test_no_piece_when_unsupported_unit_EL_plural() {
        let result = parse("[G]\n2 EL Öl")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Öl")
    }

    /// Bruch + nicht unterstützte Einheit → Menge verworfen, Notiz erhalten
    func test_no_piece_fraction_with_unsupported_unit() {
        let result = parse("[G]\n1/2 TL Ingwer, geriebener")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Ingwer")
        XCTAssertEqual(item.productDescription, "geriebener")
    }

    /// Schuss → nicht unterstützt → Menge verworfen
    func test_no_piece_when_unsupported_unit_schuss() {
        let result = parse("[A]\n2 Schuss Milch oder Sahne")
        let item = result.items[0]
        XCTAssertEqual(item.units, 1)
        XCTAssertEqual(item.measure, "")
        XCTAssertEqual(item.name, "Milch oder Sahne")
    }

    // MARK: - FAM-71: Deterministische Item-IDs (stableId)

    private let fixedListId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    /// Gleicher Name + gleiche Liste → immer dieselbe ID.
    func test_stableId_deterministicForSameInput() {
        let result = parse("[G]\nMilch")
        let item = result.items[0]
        let id1 = item.stableId(forList: fixedListId)
        let id2 = item.stableId(forList: fixedListId)
        XCTAssertEqual(id1, id2)
    }

    /// Stabiles ID ist ein gültiger UUID-String.
    func test_stableId_isValidUUIDString() {
        let result = parse("[G]\nButter")
        let id = result.items[0].stableId(forList: fixedListId)
        XCTAssertNotNil(UUID(uuidString: id))
    }

    /// Unterschiedliche Namen → unterschiedliche IDs.
    func test_stableId_differentNamesDifferentIds() {
        let result = parse("[G]\nMilch\nButter")
        let idMilch  = result.items[0].stableId(forList: fixedListId)
        let idButter = result.items[1].stableId(forList: fixedListId)
        XCTAssertNotEqual(idMilch, idButter)
    }

    /// Unterschiedliche Listen → unterschiedliche IDs.
    func test_stableId_differentListsDifferentIds() {
        let result = parse("[G]\nMilch")
        let item  = result.items[0]
        let listA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let listB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        XCTAssertNotEqual(item.stableId(forList: listA), item.stableId(forList: listB))
    }

    /// ID stimmt mit UUID.deterministicItemID überein – konsistent mit SyncEngine.
    func test_stableId_matchesDeterministicItemID() {
        let result = parse("[G]\nHähnchenbrust")
        let item = result.items[0]
        let expected = UUID.deterministicItemID(listId: fixedListId, name: item.name).uuidString
        XCTAssertEqual(item.stableId(forList: fixedListId), expected)
    }

    // MARK: - Hilfsmethode

    /// Fügt automatisch "Liste\n\n" als Listenname-Zeile vor den Inhalt.
    private func parse(_ content: String) -> ClipboardImportParser.ParseResult {
        ClipboardImportParser.parse("Liste\n\n" + content)
    }
}
