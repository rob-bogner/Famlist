/*
 ItemCategoryTests.swift
 FamlistTests
 Created on: 15.03.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Unit Tests für ItemCategory Enum und ListViewModel+CategoryProjections.
 - Prüft Fallback-Logik, Anzeigereihenfolge und Gruppierungs-Projektion.

 📝 Last Change:
 - Initial creation (FAM-63, FAM-64, FAM-65 – QA Phase 4)
 ------------------------------------------------------------------------
*/

import Foundation
import Testing
@testable import Famlist

// MARK: - ItemCategory Unit Tests

@Suite("ItemCategory")
struct ItemCategoryTests {

    // MARK: from(_:) Fallback

    @Test("nil ergibt .sonstiges")
    func fromNilReturnsSonstiges() {
        #expect(ItemCategory.from(nil) == .sonstiges)
    }

    @Test("Leerer String ergibt .sonstiges")
    func fromEmptyStringReturnsSonstiges() {
        #expect(ItemCategory.from("") == .sonstiges)
    }

    @Test("Unbekannter String ergibt .sonstiges")
    func fromUnknownStringReturnsSonstiges() {
        #expect(ItemCategory.from("Elektronik") == .sonstiges)
    }

    @Test("Gültiger rawValue wird korrekt erkannt")
    func fromValidRawValueReturnsCorrectCategory() {
        #expect(ItemCategory.from("Milchprodukte") == .milch)
        #expect(ItemCategory.from("Obst & Gemüse") == .obstGemuese)
        #expect(ItemCategory.from("Backwaren") == .backwaren)
        #expect(ItemCategory.from("Getränke") == .getraenke)
        #expect(ItemCategory.from("Haushalt") == .haushalt)
        #expect(ItemCategory.from("Tiefkühl") == .tiefkuehl)
        #expect(ItemCategory.from("Fleisch & Fisch") == .fleisch)
        #expect(ItemCategory.from("Sonstiges") == .sonstiges)
    }

    // MARK: displayOrder

    @Test("displayOrder enthält alle Kategorien")
    func displayOrderContainsAllCases() {
        #expect(ItemCategory.displayOrder.count == ItemCategory.allCases.count)
    }

    @Test("displayOrder beginnt mit Obst & Gemüse (Supermarkt-Logik)")
    func displayOrderStartsWithObstGemuese() {
        #expect(ItemCategory.displayOrder.first == .obstGemuese)
    }

    @Test("displayOrder endet mit Sonstiges")
    func displayOrderEndsWithSonstiges() {
        #expect(ItemCategory.displayOrder.last == .sonstiges)
    }

    // MARK: Icons

    @Test("Jede Kategorie hat einen SF Symbol Icon")
    func everyCategoryHasIcon() {
        for category in ItemCategory.allCases {
            #expect(!category.icon.isEmpty)
        }
    }

    // MARK: Identifiable

    @Test("id entspricht rawValue")
    func idEqualsRawValue() {
        for category in ItemCategory.allCases {
            #expect(category.id == category.rawValue)
        }
    }
}

// MARK: - CategoryProjections Tests

@Suite("ListViewModel+CategoryProjections")
struct CategoryProjectionsTests {

    // MARK: Hilfsmethode

    private func makeItem(
        id: String = UUID().uuidString,
        name: String = "Artikel",
        category: String? = nil,
        isChecked: Bool = false
    ) -> ItemModel {
        ItemModel(id: id, name: name, isChecked: isChecked, category: category)
    }

    // MARK: Leer

    @Test("Leere Liste ergibt leere Kategoriegruppen")
    func emptyListProducesNoGroups() {
        let items: [ItemModel] = []
        let grouped = groupByCategory(uncheckedItems: items)
        #expect(grouped.isEmpty)
    }

    // MARK: Alle erledigt

    @Test("Alle Items erledigt → keine Kategoriegruppen")
    func allCheckedProducesNoGroups() {
        let items = [
            makeItem(name: "Milch", category: "Milchprodukte", isChecked: true),
            makeItem(name: "Äpfel", category: "Obst & Gemüse", isChecked: true)
        ]
        let grouped = groupByCategory(uncheckedItems: items.filter { !$0.isChecked })
        #expect(grouped.isEmpty)
    }

    // MARK: Items ohne Kategorie → Sonstiges

    @Test("Items ohne Kategorie erscheinen unter .sonstiges")
    func itemsWithoutCategoryFallToSonstiges() {
        let items = [
            makeItem(name: "Unbekannt", category: nil),
            makeItem(name: "Leer", category: "")
        ]
        let grouped = groupByCategory(uncheckedItems: items)
        #expect(grouped.count == 1)
        #expect(grouped.first?.category == .sonstiges)
        #expect(grouped.first?.items.count == 2)
    }

    // MARK: Supermarkt-Reihenfolge

    @Test("Gruppen erscheinen in Supermarkt-Reihenfolge")
    func groupsAreInDisplayOrder() {
        let items = [
            makeItem(name: "Toast", category: "Backwaren"),
            makeItem(name: "Joghurt", category: "Milchprodukte"),
            makeItem(name: "Äpfel", category: "Obst & Gemüse")
        ]
        let grouped = groupByCategory(uncheckedItems: items)
        let categories = grouped.map(\.category)
        #expect(categories == [.obstGemuese, .milch, .backwaren])
    }

    // MARK: Kategorien ohne Items werden ausgelassen

    @Test("Kategorien ohne Items werden nicht eingeschlossen")
    func emptyCategoriesAreExcluded() {
        let items = [makeItem(name: "Milch", category: "Milchprodukte")]
        let grouped = groupByCategory(uncheckedItems: items)
        #expect(grouped.count == 1)
        #expect(grouped.first?.category == .milch)
    }

    // MARK: Gemischte Kategorien + erledigt

    @Test("Erledigte Items erscheinen nicht in Kategoriegruppen")
    func checkedItemsNotInCategoryGroups() {
        let items = [
            makeItem(name: "Milch", category: "Milchprodukte", isChecked: false),
            makeItem(name: "Butter", category: "Milchprodukte", isChecked: true),
            makeItem(name: "Äpfel", category: "Obst & Gemüse", isChecked: false)
        ]
        let unchecked = items.filter { !$0.isChecked }
        let grouped = groupByCategory(uncheckedItems: unchecked)

        let milchGroup = grouped.first { $0.category == .milch }
        #expect(milchGroup?.items.count == 1)
        #expect(milchGroup?.items.first?.name == "Milch")
    }

    // MARK: Artikel-Anzahl pro Gruppe

    @Test("Artikel-Anzahl pro Gruppe ist korrekt")
    func itemCountPerGroupIsCorrect() {
        let items = [
            makeItem(name: "Vollmilch", category: "Milchprodukte"),
            makeItem(name: "Joghurt", category: "Milchprodukte"),
            makeItem(name: "Butter", category: "Milchprodukte"),
            makeItem(name: "Äpfel", category: "Obst & Gemüse")
        ]
        let grouped = groupByCategory(uncheckedItems: items)

        let milchGroup = grouped.first { $0.category == .milch }
        let obstGroup = grouped.first { $0.category == .obstGemuese }

        #expect(milchGroup?.items.count == 3)
        #expect(obstGroup?.items.count == 1)
    }

    // MARK: - Hilfsfunktion (spiegelt ListViewModel+CategoryProjections Logik)

    /// Spiegelt die Logik von `ListViewModel.uncheckedItemsByCategory` ohne ViewModel-Dependency.
    private func groupByCategory(
        uncheckedItems: [ItemModel]
    ) -> [(category: ItemCategory, items: [ItemModel])] {
        let grouped = Dictionary(grouping: uncheckedItems) {
            ItemCategory.from($0.category)
        }
        return ItemCategory.displayOrder.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items)
        }
    }
}

// MARK: - ItemFormViewModel Kategorie Tests

@Suite("ItemFormViewModel – Kategorie")
@MainActor
struct ItemFormViewModelCategoryTests {

    @Test("Leere Kategorie ergibt nil in toItemModel()")
    func emptyCategoryYieldsNilInModel() {
        let vm = ItemFormViewModel()
        vm.name = "Milch"
        vm.category = ""
        let model = vm.toItemModel()
        #expect(model.category == nil)
    }

    @Test("Gesetzte Kategorie wird in toItemModel() übernommen")
    func setCategoryIsPreservedInModel() {
        let vm = ItemFormViewModel()
        vm.name = "Milch"
        vm.category = "Milchprodukte"
        let model = vm.toItemModel()
        #expect(model.category == "Milchprodukte")
    }

    @Test("Init mit existierendem Item lädt Kategorie korrekt")
    func initWithItemLoadsCategoryCorrectly() {
        let item = ItemModel(name: "Joghurt", category: "Milchprodukte")
        let vm = ItemFormViewModel(item: item)
        #expect(vm.category == "Milchprodukte")
    }

    @Test("Init mit Item ohne Kategorie ergibt leeren category-String")
    func initWithItemWithoutCategoryYieldsEmptyString() {
        let item = ItemModel(name: "Joghurt", category: nil)
        let vm = ItemFormViewModel(item: item)
        #expect(vm.category == "")
    }
}
